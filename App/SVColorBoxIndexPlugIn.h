//
//  SVColorBoxIndexPlugIn.h
//  Sandvox
//
//  Created by Dan Wood on 3/25/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVIndexPlugIn.h"

enum { kOverlayTransitionNone, kOverlayTransitionElastic, kOverlayTransitionFade };

@interface SVColorBoxIndexPlugIn : SVIndexPlugIn {

	BOOL		_useColorBox;
	
	int			_transitionType;
	BOOL		_loop;
	BOOL		_enableSlideshow;
	BOOL		_autoStartSlideshow;
	float		_slideshowSpeed;
	NSColor *	_backgroundColor;
	
}

@property  BOOL useColorBox;		// will be on for Gallery plugin, but might not be active for photo grid index.

@property  int transitionType;
@property  BOOL loop;
@property  BOOL enableSlideshow;
@property  BOOL autoStartSlideshow;
@property  float slideshowSpeed;
@property (retain) NSColor *backgroundColor;

- (NSString *)colorBoxParametersWithGroupID:(NSString *)idName;


@end
