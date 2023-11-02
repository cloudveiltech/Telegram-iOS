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
	"text/tabwriter"
	"text/template"
)

type BuildConfig struct {
	BuildNumber          uint   `json:"-"`
	ProvisioningPath     string `json:"-"`
	ApsEnvironment       string `json:"-"`
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
	IpaPath      string `json:"ipa-archive-path"`
	DsymsPath    string `json:"dsyms-archive-path"`
	DevProvision string `json:"dev-provisioning-path"`
	DistPovision string `json:"dist-provisioning-path"`
}

const USAGE = `
usage: ./make clean
	remove build outputs

usage: ./make rebuild-me
	rebuild this tool

usage: ./make test

usage: ./make build [-for sim|dev|dist] [-mode debug|release]
	build telegram

	-for	Build for simulator, development, or distribution. Controls the type of codesigning.
		simulator doesn't sign code. development requires Apple Development mobile provisioning
		files, with the device id of every device the app will be installed on. distribution
		requires Apple Distribution mobile provisioning files, and doesn't allow attaching a
		debugger to the running app.

	-mode	Embed debug symbols in unoptimized binaries, or output optimized binaries with separate
		debugging symbols.

	If a file make.json is present in the working directory, this tool will read it. If it isn't
	present, the tool will continue as if the file had the following contents:
		{
			"ipa-archive-path": null,
			"dsyms-archive-path": null,
			"dev-provisioning-path": "../ProvisionDev",
			"dist-provisioning-path": "../ProvisionDist"
		}
`

// VARIABLES contains the variables.bzl template
const VARIABLES = `
telegram_bazel_path = "/does/not/exist/bazel"
telegram_use_xcode_managed_codesigning = False
telegram_bundle_id = "{{ .BundleId }}"
telegram_api_id = "{{ .ApiId }}"
telegram_api_hash = "{{ .ApiHash }}"
telegram_team_id = "{{ .TeamId }}"
telegram_app_center_id = "0"
telegram_is_internal_build = "{{ printf "%t" (eq "development" .ApsEnvironment) }}"
telegram_is_appstore_build = "{{ printf "%t" (eq "production" .ApsEnvironment) }}"
telegram_appstore_id = "{{ .AppStoreId }}"
telegram_app_specific_url_scheme = "{{ .AppSpecificUrlScheme }}"
telegram_premium_iap_product_id = "{{ .PremiumIapProductId }}"
telegram_aps_environment = "{{ .ApsEnvironment }}"
telegram_enable_siri = {{ if .EnableSiri -}} True {{- else -}} False {{- end }}
telegram_enable_icloud = {{ if .EnableIcloud -}} True {{- else -}} False {{- end }}
telegram_enable_watch = True
`

// usage outputs command usage to the given writer
func usage(w io.Writer) {
	tw := tabwriter.NewWriter(w, 0, 8, 0, '\t', 0)
	fmt.Fprint(tw, USAGE)
	tw.Flush()
}

// runBazel run a bazel command, sending all it's output to the given writer
func runBazel(w io.Writer, args ...string) error {
	bazel := exec.Command("bazel", args...)
	bazel.Stdout = w
	bazel.Stderr = w
	bazel.Env = append(os.Environ(), "USE_BAZEL_VERSION=6.3.2")
	return bazel.Run()
}

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
			err := runBazel(os.Stderr, "clean", "--expunge")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed running bazel: %v\n", err)
				return 1
			}
			return 0
		case "build":
			// parse command line args
			var buildFor, buildMode string
			flag.StringVar(&buildFor, "for", "sim", "")
			flag.StringVar(&buildMode, "mode", "debug", "")
			flag.CommandLine.Usage = func() {
				usage(os.Stderr)
			}
			flag.CommandLine.Parse(os.Args[2:])

			// parse our configuration
			makeConfig := MakeConfig{
				DevProvision: "../ProvisionDev",
				DistPovision: "../ProvisionDist",
			}
			err := withOpenFile("make.json", func(file *os.File) error {
				return json.NewDecoder(file).Decode(&makeConfig)
			})
			if err != nil && !errors.Is(err, fs.ErrNotExist) {
				fmt.Fprintf(os.Stderr, "Failed reading make configuration: %v\n", err)
				return 1
			}

			// figure out where the build configuration and provisioning profiles are
			provisionPath := makeConfig.DevProvision
			if buildFor == "dist" {
				provisionPath = makeConfig.DistPovision
			}

			// read and decode the build config
			var buildConfig BuildConfig
			err = withOpenFile(filepath.Join(provisionPath, "configuration.json"), func(configJsonFile *os.File) error {
				return json.NewDecoder(configJsonFile).Decode(&buildConfig)
			})
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed reading build configuration: %v\n", err)
				return 1
			}
			switch buildFor {
			case "dev":
				buildConfig.ApsEnvironment = "development"
			case "dist":
				buildConfig.ApsEnvironment = "production"
			default:
				// this will probably cause a build error
				buildConfig.ApsEnvironment = "unknown"
			}

			// read the Telegram version we will build
			var versions struct {
				App string `json:"app"`
			}
			err = withOpenFile("versions.json", func(versionsFile *os.File) error {
				return json.NewDecoder(versionsFile).Decode(&versions)
			})
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed reading telegram version: %v\n", err)
				return 1
			}
			appVersion := versions.App

			// read the build number to use
			buildNumber := 0
			_ = withOpenFile("buildNumber.txt", func(bnumFile *os.File) error {
				_, err := fmt.Fscanf(bnumFile, "%d", &buildNumber)
				return err
			})

			cfgdir := "build-input/configuration-repository"

			// create the dir to contain the build configuration repository
			err = os.MkdirAll(cfgdir, 0755)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating %s: %v\n", cfgdir, err)
				return 1
			}

			// make the build configuration repository a bazel repo
			err = os.WriteFile(filepath.Join(cfgdir, "WORKSPACE"), []byte{}, 0644)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating WORKSPACE: %v\n", err)
				return 1
			}
			err = os.WriteFile(filepath.Join(cfgdir, "BUILD"), []byte{}, 0644)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating BUILD: %v\n", err)
				return 1
			}

			// write the build configuration variables to the repo
			varsFile, err := os.Create(filepath.Join(cfgdir, "variables.bzl"))
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating variables.bzl: %v\n", err)
				return 1
			}
			varsTmpl := template.Must(template.New("variables.bzl").Parse(VARIABLES))
			err = varsTmpl.Execute(varsFile, buildConfig)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed writing variables.bzl: %v\n", err)
				return 1
			}

			// create the dir for the provisioning profiles module in the config repo
			err = os.RemoveAll(filepath.Join(cfgdir, "provisioning"))
			if err != nil && !errors.Is(err, os.ErrNotExist) {
				fmt.Fprintf(os.Stderr, "Failed removing stale provisioning: %v\n", err)
				return 1
			}
			err = os.Mkdir(filepath.Join(cfgdir, "provisioning"), 0755)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating provisioning: %v\n", err)
				return 1
			}

			// find the provisioning profiles to use
			found, err := filepath.Glob(filepath.Join(provisionPath, "*.mobileprovision"))
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed finding provisioning profiles: %v\n", err)
				return 1
			}

			// create the provisioning profiles module, and symlink the
			// provisioning profiles to use into it
			buildFile, err := os.Create(filepath.Join(cfgdir, "provisioning", "BUILD"))
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating provisioning/BUILD: %v\n", err)
				return 1
			}
			defer buildFile.Close()
			_, err = fmt.Fprintf(buildFile, "exports_files([\n")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed writing provisioning/BUILD: %v\n", err)
				return 1
			}
			for _, src := range found {
				name := filepath.Base(src)
				dst := filepath.Join(cfgdir, "provisioning", name)
				src, err = filepath.Abs(src)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed creating provisioning profile symlinks: %v\n", err)
					return 1
				}
				err = os.Symlink(src, dst)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed creating provisioning profile symlinks: %v\n", err)
					return 1
				}
				_, err = fmt.Fprintf(buildFile, "\t\"%s\",\n", name)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed writing provisioning/BUILD: %v\n", err)
					return 1
				}
			}
			_, err = fmt.Fprintf(buildFile, "])\n")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed writing provisioning/BUILD: %v\n", err)
				return 1
			}
			buildFile.Close()

			// run bazel
			args := []string{
				"build", "Telegram/Telegram", "--announce_rc", "--verbose_failures",
				"--features=swift.use_global_module_cache", "--experimental_remote_cache_async",
				"--features=swift.skip_function_bodyies_for_derived_files",
				"--apple_generate_dsym", "--output_groups=+dsyms",
				"--features=-no_warn_duplicate_libraries",
				fmt.Sprintf("--override_repository=build_configuration=%s", cfgdir),
				fmt.Sprintf("--jobs=%d", runtime.NumCPU()), "--watchos_cpus=arm64_32",
				fmt.Sprintf("--define=buildNumber=%d", buildNumber),
				fmt.Sprintf("--define=telegramVersion=%s", appVersion),
			}

			switch buildFor {
			case "dist":
				args = append(args,
					"--define=apple.add_debugger_entitlement=no",
					"--apple_bitcode=watchos=none",
				)
			default:
				args = append(args, "--define=apple.add_debugger_entitlement=yes")
			}

			switch buildFor {
			case "sim":
				args = append(args,
					"--//Telegram:disableProvisioningProfiles",
					fmt.Sprintf("--ios_multi_cpus=sim_%s", runtime.GOARCH),
				)
			default:
				args = append(args, "--ios_multi_cpus=arm64")
			}

			switch buildMode {
			case "debug":
				args = append(args,
					"-c", "dbg", "--features=swift.enable_batch_mode",
					"--//Telegram:disableStripping",
					fmt.Sprintf("--swiftcopt=-j%d", min(runtime.NumCPU()-1, 1)),
				)
			case "release":
				args = append(args,
					"-c", "opt", "--features=swift.opt_uses_wmo", "--swiftcopt=-num-threads",
					"--swiftcopt=1", "--swiftcopt=-j1", "--features=dead_strip",
					"--objc_enable_binary_stripping",
				)
			}

			buildLog, err := os.Create("build.log")
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed creating build.log: %v\n", err)
				return 1
			}

			err = runBazel(io.MultiWriter(os.Stdout, buildLog), args...)
			if err != nil {
				fmt.Fprintf(os.Stderr, "bazel error: %v\n", err)
				fmt.Fprintf(os.Stderr, "Full build log at build.log\n")
				return 2
			}

			// update the build number
			err = os.WriteFile("buildNumber.txt", []byte(fmt.Sprintf("%d\n", buildNumber+1)), 0644)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed incrementing build number: %v\n", err)
				return 3
			}

			archiveName := fmt.Sprintf("Telegram_%s_%s_%d", buildFor, buildMode, buildNumber)

			// copy the IPA to the archive
			if makeConfig.IpaPath != "" {
				err = os.MkdirAll(makeConfig.IpaPath, 0755)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed creating IPA archive: %v\n", err)
					return 3
				}

				err = copyFile("bazel-bin/Telegram/Telegram.ipa", makeConfig.IpaPath+"/"+archiveName+".ipa")
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed copying IPA to archive: %v\n", err)
					return 3
				}
			}

			// copy the dSYMs to the archive
			if makeConfig.DsymsPath != "" {
				dsyms, _ := filepath.Glob("bazel-bin/Telegram/*.dSYM")
				if dsyms != nil && len(dsyms) != 0 {
					err = os.MkdirAll(makeConfig.DsymsPath+"/"+archiveName+".dSYMs", 0755)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Failed creating dSYM archive: %v\n", err)
						return 3
					}
					for _, dsym := range dsyms {
						dst := makeConfig.DsymsPath + "/" + archiveName + ".dSYMs/" + filepath.Base(dsym)
						err = copyDir(dsym, dst)
						if err != nil {
							fmt.Fprintf(os.Stderr, "Failed copying dSYM to archive: %v\n", err)
							return 3
						}
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
