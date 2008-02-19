//
//  PageCounterPagelet.h
//  PageCounterPagelet
//
//  Created by Greg Hulands on 1/09/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sandvox.h>

@class WebView;

@interface PageCounterPagelet : KTAbstractPluginDelegate
{
	IBOutlet NSPopUpButton *oTheme;
}

@end

extern NSString *PCThemeKey;
extern NSString *PCWidthKey;
extern NSString *PCHeightKey;
extern NSString *PCImagesPathKey;