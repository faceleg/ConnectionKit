//
//  SVColorBoxIndexPlugIn.h
//  Sandvox
//
//  Created by Dan Wood on 3/25/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVIndexPlugIn.h"

enum { kOverlayTransitionNone, kOverlayTransitionElastic, kOverlayTransitionFade };
enum { kSlideshowNone, kSlideshowManual, kSlideshowAutomatic };

@class SVPlugInContext;

@interface SVColorBoxIndexPlugIn : SVIndexPlugIn {

	BOOL		_useColorBox;
	
	int			_transitionType;
	BOOL		_loop;
	BOOL		_enableSlideshow;
	BOOL		_autoStartSlideshow;
	float		_slideshowSpeed;
	NSColor *	_backgroundColor;
	
	int			_slideshowType;	// transient, just for binding to the popup.
	
}

@property (nonatomic) BOOL useColorBox;		// will be on for Gallery plugin, but might not be active for photo grid index.

@property (nonatomic) int transitionType;
@property (nonatomic) BOOL loop;
@property (nonatomic) BOOL enableSlideshow;
@property (nonatomic) BOOL autoStartSlideshow;
@property (nonatomic) float slideshowSpeed;
@property (nonatomic, retain) NSColor *backgroundColor;

@property (nonatomic) int slideshowType;

- (NSString *)colorBoxParametersWithGroupID:(NSString *)idName;
- (NSString *)parameterLineForPreviewOnly:(id<SVPlugInContext>)context;

@end
