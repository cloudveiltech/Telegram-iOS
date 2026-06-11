#import <UIKit/UIKit.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // CloudVeil: the following line has the original Telegram app delegate replaced
        // by a CloudVeil subclass of the original app delegate
        return UIApplicationMain(argc, argv, @"Application", @"CVAppDelegate");
    }
}
