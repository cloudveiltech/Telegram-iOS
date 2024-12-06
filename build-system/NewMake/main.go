// NewMake is a replacement for Telegram's bloated Make.py. I'm tired of fixing
// it every time I need to change how I run builds.

package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"text/tabwriter"
	"text/template"
)

type Config struct {
	BuildNumber      uint
	ProvisioningPath string
	BuildFor         string
	BuildMode        string
	AppVersion       string
	BazelPath        string
	ShipLogs         bool
	FakeMode         bool
	SkipArchive      bool
	BazelConfig      *BazelConfig
	MakeConfig       *MakeConfig
}

type BazelConfig struct {
	BundleId             string `json:"bundle_id"`
	ApiId                string `json:"api_id"`
	ApiHash              string `json:"api_hash"`
	TeamId               string `json:"team_id"`
	AppStoreId           string `json:"appstore_id"`
	AppSpecificUrlScheme string `json:"app_specific_url_scheme"`
	PremiumIapProductId  string `json:"premium_iap_product_id"`
	EnableSiri           bool   `json:"enable_siri"`
	EnableIcloud         bool   `json:"enable_icloud"`
}

type MakeConfig struct {
	IpaPath        string             `json:"ipa-archive-path"`
	IpaPathTmpl    *template.Template `json:"-"`
	DsymsPath      string             `json:"dsyms-archive-path"`
	DsymsPathTmpl  *template.Template `json:"-"`
	DevProvision   string             `json:"dev-provisioning-path"`
	DistPovision   string             `json:"dist-provisioning-path"`
	AdHocProvision string             `json:"adhoc-provisioning-path"`
}

// ArchiveData is the data object used when executing the archive destination templates
type ArchiveData struct {
	BundleID    string
	BundleName  string
	BuildNumber uint
	Version     string
	BuildFor    string
	BuildMode   string
}

// the trailing whitespace in this literal is important to align the text properly
const USAGE = `
usage: ./make clean
	remove build outputs

usage: ./make rebuild-me
	rebuild this tool

usage: ./make test

usage: ./make project
	generate an Xcode project

usage: ./make build [-noarchive] [-shiplogs] [-fakecv] [-for sim|dev|dist] [-mode debug|release]
	build telegram

	-for	Build for simulator, development, or distribution. Controls the type of codesigning.
		simulator doesn't sign code. development requires Apple Development mobile provisioning
		files, with the device id of every device the app will be installed on. distribution
		requires Apple Distribution mobile provisioning files, and doesn't allow attaching a
		debugger to the running app.
		
	-mode	Embed debug symbols in unoptimized binaries, or output optimized binaries with separate
		debugging symbols.
		
	-noarchive	Don't copy the build outputs to the archive paths. Don't bump the build number.
		
	-shiplogs	Enable uploading telegram logs to Sandy Creek Technologies servers.
		
	-fakecv	Use fake response from CloudVeil servers

	If a file make.json is present in the working directory, this tool will read it. If it isn't
	present, the tool will continue as if the file had the following contents:
		{
			"ipa-archive-path": null,
			"dsyms-archive-path": null,
			"dev-provisioning-path": "../ProvisionDev",
			"dist-provisioning-path": "../ProvisionDist",
			"adhoc-provisioning-path": "../ProvisionAdHoc"
		}
`

// VARIABLES contains the variables.bzl template
const VARIABLES = `
telegram_bazel_path = "{{ .BazelPath }}"
telegram_use_xcode_managed_codesigning = False
telegram_bundle_id = "{{ .BazelConfig.BundleId }}"
telegram_api_id = "{{ .BazelConfig.ApiId }}"
telegram_api_hash = "{{ .BazelConfig.ApiHash }}"
telegram_team_id = "{{ .BazelConfig.TeamId }}"
telegram_app_center_id = "0"
telegram_is_internal_build = "{{ printf "%t" (or (eq "sim" .BuildFor) (eq "dev" .BuildFor)) }}"
telegram_is_appstore_build = "{{ printf "%t" (eq "dist" .BuildFor) }}"
telegram_appstore_id = "{{ .BazelConfig.AppStoreId }}"
telegram_app_specific_url_scheme = "{{ .BazelConfig.AppSpecificUrlScheme }}"
telegram_premium_iap_product_id = "{{ .BazelConfig.PremiumIapProductId }}"
{{ if (or (eq "dist" .BuildFor) (eq "adhoc" .BuildFor)) -}}
telegram_aps_environment = "production"
{{- else -}}
telegram_aps_environment = "development"
{{- end }}
telegram_enable_siri = {{ if .BazelConfig.EnableSiri -}} True {{- else -}} False {{- end }}
telegram_enable_icloud = {{ if .BazelConfig.EnableIcloud -}} True {{- else -}} False {{- end }}
telegram_enable_watch = True
{{ if .ShipLogs -}}
cloudveil_shiplogs = True
{{- else -}}
cloudveil_shiplogs = False
{{- end }}
`

// usage outputs command usage to the given writer
func usage(w io.Writer) {
	tw := tabwriter.NewWriter(w, 4, 8, 1, ' ', 0)
	fmt.Fprint(tw, USAGE)
	tw.Flush()
}

const BAZEL_VERSION_ENV = "USE_BAZEL_VERSION=7.3.1"

// runCmd runs an arbitrary command, passing through its stdout and stderr to ours
func runCmd(cmd string, args ...string) error {
	proc := exec.Command(cmd, args...)
	proc.Stderr = os.Stderr
	proc.Stdout = os.Stdout
	return proc.Run()
}

// withOpenFile opens a file, calls fun, then closes it. The file will be
// closed if fun panics.
func withOpenFile(path string, fun func(file *os.File) error) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	return fun(file)
}

// copyFile copies the file at src to dst. dst will be created with src's
// permissions if dst doesn't already exist.
func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()
	srcInfo, err := srcFile.Stat()
	if err != nil {
		return err
	}
	dstFile, err := os.OpenFile(dst, os.O_WRONLY|os.O_TRUNC|os.O_CREATE, srcInfo.Mode())
	if err != nil {
		return err
	}
	defer dstFile.Close()
	_, err = io.Copy(dstFile, srcFile)
	return err
}

// copyDir copies the directory at src to dst. dst will be created with src's
// permissions.
func copyDir(src, dst string) error {
	// for better error reporting
	_, err := os.Stat(src)
	if err != nil {
		return err
	}
	err = os.RemoveAll(dst)
	if err != nil {
		return err
	}
	return exec.Command("cp", "-R", src, dst).Run()
}

func readConfig(cmd string) (*Config, error) {
	cfg := &Config{BuildFor: "dev", BuildMode: "debug", SkipArchive: true}
	flag.Func("for", "", func(s string) error {
		switch s {
		case "sim", "dev", "dist", "adhoc":
			cfg.BuildFor = s
			return nil
		default:
			return fmt.Errorf("unknown build for: %q", s)
		}
	})
	flag.Func("mode", "", func(s string) error {
		switch s {
		case "debug", "release":
			cfg.BuildMode = s
			return nil
		default:
			return fmt.Errorf("unknown build mode: %q", s)
		}
	})
	flag.BoolVar(&cfg.SkipArchive, "noarchive", false, "")
	flag.BoolVar(&cfg.ShipLogs, "shiplogs", false, "")
	flag.BoolVar(&cfg.FakeMode, "fakecv", false, "")
	flag.CommandLine.Usage = func() {
		usage(os.Stderr)
	}
	flag.CommandLine.Parse(os.Args[2:])

	cfg.MakeConfig = &MakeConfig{
		DevProvision:   "../ProvisionDev",
		DistPovision:   "../ProvisionDist",
		AdHocProvision: "../ProvisionAdHoc",
	}
	err := withOpenFile("make.json", func(file *os.File) error {
		return json.NewDecoder(file).Decode(cfg.MakeConfig)
	})
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, fmt.Errorf("Failed reading make configuration: %v\n", err)
	}
	cfg.MakeConfig.IpaPathTmpl, err = template.New("ipa-path").Parse(cfg.MakeConfig.IpaPath)
	if err != nil {
		return nil, fmt.Errorf("Failed parsing ipa-archive-path template: %v\n", err)
	}
	cfg.MakeConfig.DsymsPathTmpl, err = template.New("dsyms-path").Parse(cfg.MakeConfig.DsymsPath)
	if err != nil {
		return nil, fmt.Errorf("Failed parsing dsyms-archive-path template: %v\n", err)
	}

	// figure out where the build configuration and provisioning profiles are
	switch cfg.BuildFor {
	case "sim", "dev":
		cfg.ProvisioningPath = cfg.MakeConfig.DevProvision
	case "dist":
		cfg.ProvisioningPath = cfg.MakeConfig.DistPovision
	case "adhoc":
		cfg.ProvisioningPath = cfg.MakeConfig.AdHocProvision
	}

	// read and decode the build config
	cfg.BazelConfig = &BazelConfig{}
	bazelConfigFile := filepath.Join(cfg.ProvisioningPath, "configuration.json")
	err = withOpenFile(bazelConfigFile, func(configJsonFile *os.File) error {
		return json.NewDecoder(configJsonFile).Decode(cfg.BazelConfig)
	})
	if err != nil {
		return nil, fmt.Errorf("Failed reading bazel configuration: %v\n", err)
	}

	// read the Telegram version we will build
	var versions struct {
		App string `json:"app"`
	}
	err = withOpenFile("versions.json", func(versionsFile *os.File) error {
		return json.NewDecoder(versionsFile).Decode(&versions)
	})
	if err != nil {
		return nil, fmt.Errorf("Failed reading telegram version: %v\n", err)
	}
	cfg.AppVersion = versions.App

	// find the Bazel we will use
	cfg.BazelPath, err = exec.LookPath("bazel")
	if err != nil {
		return nil, fmt.Errorf("Failed locating bazel: %v\n", err)
	}

	// read the build number to use
	_ = withOpenFile("buildNumber.txt", func(bnumFile *os.File) error {
		_, err := fmt.Fscanf(bnumFile, "%d", &cfg.BuildNumber)
		return err
	})

	return cfg, nil
}

func updateBuildConfigRepo(cfgdir string, cfg *Config) error {
	// create the dir to contain the build configuration repository
	err := os.MkdirAll(cfgdir, 0755)
	if err != nil {
		return fmt.Errorf("Failed creating %s: %v\n", cfgdir, err)
	}

	// make the build configuration repository a bazel repo
	err = os.WriteFile(filepath.Join(cfgdir, "WORKSPACE"), []byte{}, 0644)
	if err != nil {
		return fmt.Errorf("Failed creating WORKSPACE: %v\n", err)
	}
	err = os.WriteFile(filepath.Join(cfgdir, "BUILD"), []byte{}, 0644)
	if err != nil {
		return fmt.Errorf("Failed creating BUILD: %v\n", err)
	}

	// write the build configuration variables to the repo
	varsFile, err := os.Create(filepath.Join(cfgdir, "variables.bzl"))
	if err != nil {
		return fmt.Errorf("Failed creating variables.bzl: %v\n", err)
	}
	varsTmpl := template.Must(template.New("variables.bzl").Parse(VARIABLES))
	err = varsTmpl.Execute(varsFile, cfg)
	if err != nil {
		return fmt.Errorf("Failed writing variables.bzl: %v\n", err)
	}

	// create the dir for the provisioning profiles module in the config repo
	err = os.RemoveAll(filepath.Join(cfgdir, "provisioning"))
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("Failed removing stale provisioning: %v\n", err)
	}
	err = os.Mkdir(filepath.Join(cfgdir, "provisioning"), 0755)
	if err != nil {
		return fmt.Errorf("Failed creating provisioning: %v\n", err)
	}

	// find the provisioning profiles to use
	found, err := filepath.Glob(filepath.Join(cfg.ProvisioningPath, "*.mobileprovision"))
	if err != nil {
		return fmt.Errorf("Failed finding provisioning profiles: %v\n", err)
	}

	// create the provisioning profiles module, and symlink the
	// provisioning profiles to use into it
	buildFile, err := os.Create(filepath.Join(cfgdir, "provisioning", "BUILD"))
	if err != nil {
		return fmt.Errorf("Failed creating provisioning/BUILD: %v\n", err)
	}
	defer buildFile.Close()
	_, err = fmt.Fprintf(buildFile, "exports_files([\n")
	if err != nil {
		return fmt.Errorf("Failed writing provisioning/BUILD: %v\n", err)
	}
	for _, src := range found {
		name := filepath.Base(src)
		dst := filepath.Join(cfgdir, "provisioning", name)
		src, err = filepath.Abs(src)
		if err != nil {
			return fmt.Errorf("Failed creating provisioning profile symlinks: %v\n", err)
		}
		err = os.Symlink(src, dst)
		if err != nil {
			return fmt.Errorf("Failed creating provisioning profile symlinks: %v\n", err)
		}
		_, err = fmt.Fprintf(buildFile, "\t\"%s\",\n", name)
		if err != nil {
			return fmt.Errorf("Failed writing provisioning/BUILD: %v\n", err)
		}
	}
	_, err = fmt.Fprintf(buildFile, "])\n")
	if err != nil {
		return fmt.Errorf("Failed writing provisioning/BUILD: %v\n", err)
	}
	return nil
}

func bazelArgs(cfg *Config, cfgdir, cmd string, extras ...string) []string {
	args := []string{cmd,
		fmt.Sprintf("--override_repository=build_configuration=%s", cfgdir),
	}

	args = append(args, extras...)

	if cmd != "query" {
		args = append(args,
			"--features=swift.use_global_module_cache", "--experimental_remote_cache_async",
			"--features=swift.skip_function_bodies_for_derived_files",
			"--features=-no_warn_duplicate_libraries", "--watchos_cpus=arm64_32",
			"--apple_generate_dsym", "--output_groups=+dsyms",
			fmt.Sprintf("--jobs=%d", runtime.NumCPU()),
			fmt.Sprintf("--define=buildNumber=%d", cfg.BuildNumber),
			fmt.Sprintf("--define=telegramVersion=%s", cfg.AppVersion),
		)

		switch cfg.BuildFor {
		case "dist", "adhoc":
			args = append(args,
				"--define=apple.add_debugger_entitlement=no",
			)
		default:
			args = append(args, "--define=apple.add_debugger_entitlement=yes")
		}

		switch cfg.BuildFor {
		case "sim":
			args = append(args,
				"--//Telegram:disableProvisioningProfiles",
				fmt.Sprintf("--ios_multi_cpus=sim_%s", runtime.GOARCH),
			)
		default:
			args = append(args, "--ios_multi_cpus=arm64")
		}

		switch cfg.BuildMode {
		case "debug":
			args = append(args,
				"-c", "dbg", "--features=swift.enable_batch_mode",
				"--//Telegram:disableStripping", "--strip=never",
				fmt.Sprintf("--swiftcopt=-j%d", min(runtime.NumCPU()-1, 1)),
			)
		case "release":
			args = append(args,
				"-c", "opt", "--features=swift.opt_uses_wmo", "--swiftcopt=-num-threads",
				"--swiftcopt=1", "--swiftcopt=-j1", "--features=dead_strip",
				"--objc_enable_binary_stripping",
			)
		}
	} else {
		if cfg.BuildFor == "sim" {
			args = append(args, "--//Telegram:disableProvisioningProfiles")
		}
		if cfg.BuildMode == "debug" {
			args = append(args, "--//Telegram:disableStripping")
		}
	}

	if cfg.FakeMode {
		args = append(args, "--//CloudVeil/SecurityManager:FakeMode")
	}

	return args
}

func main() {
	os.Exit(func() int {
		// Make sure we have a command
		if len(os.Args) < 2 {
			fmt.Fprintln(os.Stderr, "No command specified")
			usage(os.Stderr)
			return 1
		}
		cmd := os.Args[1]

		switch cmd {
		case "-h", "-help", "--help":
			usage(os.Stdout)
			return 0
		case "rebuild-me":
			// compile ourselves
			cmd := exec.Command("go", "-C", "build-system/NewMake", "build")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			err := cmd.Run()
			if err == nil {
				// if the compile succeeded, overwrite our binary
				os.Rename("build-system/NewMake/NewMake", "make")
			}
			return cmd.ProcessState.ExitCode()
		case "clean":
			bazel := exec.Command("bazel", "clean", "--expunge")
			bazel.Stdout = os.Stdout
			bazel.Stderr = os.Stderr
			bazel.Env = append(os.Environ(), BAZEL_VERSION_ENV)
			err := bazel.Run()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed running bazel: %v\n", err)
				return 1
			}
			return 0
		case "query":
			if len(os.Args) < 3 {
				fmt.Fprintln(os.Stderr, "No query specified")
				usage(os.Stderr)
				return 1
			}

			cfgdir := "build-input/configuration-repository"

			cfg, err := readConfig(cmd)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
			}
			err = updateBuildConfigRepo(cfgdir, cfg)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
			}

			args := bazelArgs(cfg, cfgdir, "query", os.Args[2:]...)

			bazel := exec.Command("bazel", args...)
			bazel.Stdout = os.Stdout
			bazel.Stderr = os.Stderr
			bazel.Env = append(os.Environ(), BAZEL_VERSION_ENV)
			err = bazel.Run()
			if err != nil {
				fmt.Fprintf(os.Stderr, "bazel error: %v\n", err)
				return 2
			}
			return 0
		case "project":
			cfgdir := "build-input/xcode-config-repo"

			cfg, err := readConfig(cmd)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
			}
			err = updateBuildConfigRepo(cfgdir, cfg)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
			}

			buildArgs := []string{}
			runArgs := []string{}
			for _, arg := range bazelArgs(cfg, cfgdir, "build") {
				if strings.HasPrefix(arg, "--ios_multi_cpus=") {
					continue
				}
				if arg != "build" {
					buildArgs = append(buildArgs, arg)
				}
				if strings.HasPrefix(arg, "--//") {
					runArgs = append(runArgs, arg)
				}
			}

			// The xcode project generator, in a COMPLETELY ASININE
			// decision, thinks it's reasonable to call bazel like so by
			// default: `PATH=/bin:/usr/bin`. Since we need a Homebrew
			// installed tool on the path, we have to fix it with this
			// kludge. (The other fix is worse: it could cause merge
			// conflicts).
			buildArgs = append(buildArgs, fmt.Sprintf("--action_env=PATH=%s", os.Getenv("PATH")))

			bazelrc, err := os.Create("xcodeproj.bazelrc")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed writing xcodeproj.bazelrc: %v\n", err)
				return 1
			}
			defer bazelrc.Close()
			_, err = bazelrc.WriteString("common")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed writing xcodeproj.bazelrc: %v\n", err)
				return 1
			}
			for _, arg := range buildArgs {
				_, err = fmt.Fprintf(bazelrc, " %s", arg)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed writing xcodeproj.bazelrc: %v\n", err)
					return 1
				}
			}
			_, err = bazelrc.WriteString("\n")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed writing xcodeproj.bazelrc: %v\n", err)
				return 1
			}
			bazelrc.Close()

			runArgs = append([]string{"run", "//Telegram:Telegram_xcodeproj",
				fmt.Sprintf("--override_repository=build_configuration=%s", cfgdir),
				fmt.Sprintf("--jobs=%d", runtime.NumCPU()), "--noenable_bzlmod",
			}, runArgs...)
			bazel := exec.Command("bazel", runArgs...)
			bazel.Stdout = os.Stdout
			bazel.Stderr = os.Stderr
			bazel.Env = append(os.Environ(), BAZEL_VERSION_ENV)
			err = bazel.Run()
			if err != nil {
				return 2
			}
		case "build", "test":
			cfgdir := "build-input/configuration-repository"

			cfg, err := readConfig(cmd)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
			}
			err = updateBuildConfigRepo(cfgdir, cfg)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
			}

			// run bazel
			var args []string
			if cmd == "test" {
				args = bazelArgs(cfg, cfgdir, "test", "Tests/AllTests")
			} else {
				args = bazelArgs(cfg, cfgdir, "build", "Telegram/Telegram")
			}

			buildLog, err := os.Create("build.log")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating build.log: %v\n", err)
				return 1
			}

			bazelOut := io.MultiWriter(os.Stdout, buildLog)
			bazel := exec.Command("bazel", args...)
			bazel.Stdout = bazelOut
			bazel.Stderr = bazelOut
			bazel.Env = append(os.Environ(), BAZEL_VERSION_ENV)
			err = bazel.Run()
			if err != nil {
				fmt.Fprintf(os.Stderr, "bazel error: %v\n", err)
				fmt.Fprintf(os.Stderr, "Full build log at build.log\n")
				return 2
			}

			if !cfg.SkipArchive {
				// update the build number
				err = os.WriteFile("buildNumber.txt", []byte(fmt.Sprintf("%d\n", cfg.BuildNumber+1)), 0644)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed incrementing build number: %v\n", err)
					return 3
				}

				// fill out the data given to the archive path templates
				sb := strings.Builder{}
				bundleIdElems := strings.Split(cfg.BazelConfig.BundleId, ".")
				bundleName := ""
				if len(bundleIdElems) > 0 {
					bundleName = bundleIdElems[len(bundleIdElems)-1]
				}
				archiveData := ArchiveData{
					BundleID:    cfg.BazelConfig.BundleId,
					BundleName:  bundleName,
					BuildNumber: cfg.BuildNumber,
					Version:     cfg.AppVersion,
					BuildFor:    cfg.BuildFor,
					BuildMode:   cfg.BuildMode,
				}

				// copy the IPA to the archive
				err = cfg.MakeConfig.IpaPathTmpl.Execute(&sb, archiveData)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed running IPA archive path template: %v\n", err)
				} else if ipaPath := sb.String(); ipaPath != "" {
					err = os.MkdirAll(filepath.Dir(ipaPath), 0755)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Failed creating IPA archive dir: %v\n", err)
						return 3
					}

					err = copyFile("bazel-bin/Telegram/Telegram.ipa", ipaPath)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Failed copying IPA to archive: %v\n", err)
						return 3
					}
					fmt.Printf("IPA copied to %q\n", ipaPath)
				}
				sb.Reset()

				// copy the dSYMs to the archive
				err = cfg.MakeConfig.DsymsPathTmpl.Execute(&sb, archiveData)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed running dSYMs archive path template: %v\n", err)
				} else if dsymsPath := sb.String(); dsymsPath != "" {
					dsyms, _ := filepath.Glob("bazel-bin/Telegram/*.dSYM")
					if dsyms != nil && len(dsyms) != 0 {
						err = os.MkdirAll(dsymsPath, 0755)
						if err != nil {
							fmt.Fprintf(os.Stderr, "Failed creating dSYMs archive: %v\n", err)
							return 3
						}
						for _, dsym := range dsyms {
							dst := dsymsPath + "/" + filepath.Base(dsym)
							err = copyDir(dsym, dst)
							if err != nil {
								fmt.Fprintf(os.Stderr, "Failed copying dSYM to archive: %v\n", err)
								return 3
							}
						}
						fmt.Printf("dSYMs copied to %q\n", dsymsPath)
					}
				}
			}
		default:
			fmt.Fprintln(os.Stderr, "Unknown command")
			usage(os.Stderr)
		}
		return 1
	}())
}
