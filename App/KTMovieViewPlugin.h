//
//  KTMovieViewPlugin.h
//  Marvel
//
//  Created by Dan Wood on 3/11/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <QTKit/QTKit.h>


@interface KTMovieViewPlugin : QTMovieView <WebPlugInViewFactory>
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
