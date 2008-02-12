
#import <AppKit/AppKit.h>

@interface MovieView : NSMovieView 
{
    NSDictionary *_arguments;
    BOOL _loadedMovie;
    // This instance variable is required on the WWDC and the WWDC Panther beta
    // builds.  It exposes the property to the Objective-C/JavaScripting
    // binding.  However, the setMuted: and isMuted methods on the NSMovieView
    // superclass are called as Key/Value setters and getters, rather than
    // the value of this instance variable being set.
    BOOL muted;
}

- (void)setArguments:(NSDictionary *)arguments;

@end
