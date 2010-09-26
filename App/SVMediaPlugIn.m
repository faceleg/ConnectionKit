//
//  SVMediaPlugIn.m
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaPlugIn.h"


@implementation SVMediaPlugIn

- (void)awakeFromPasteboardContents:(id)contents ofType:(NSString *)type;
{
    
}

#pragma mark Properties

- (SVMediaRecord *)media; { return [[self container] media]; }
- (NSURL *)externalSourceURL; { return [[self container] externalSourceURL]; }

- (BOOL)validateTypeToPublish:(NSString **)type error:(NSError **)errror;
{
    return YES;
}

#pragma mark Metrics

+ (BOOL)isExplicitlySized; { return YES; }

- (CGSize)originalSize;
{
    CGSize result = CGSizeZero;
    
    SVMediaGraphic *container = [self container];
    
    SVMediaRecord *media = [container media];
    if (media)
	{
		NSNumber *naturalWidth = container.naturalWidth;
		NSNumber *naturalHeight = container.naturalHeight;
		// Try to get cached natural size first
		if (nil != naturalWidth && nil != naturalHeight)
		{
			result = CGSizeMake([naturalWidth floatValue], [naturalHeight floatValue]);
		}
		else	// ask the media for it, and cache it.
		{
			result = [media originalSize];
			container.naturalWidth = [NSNumber numberWithFloat:result.width];
			container.naturalHeight = [NSNumber numberWithFloat:result.height];
		}
	}
	if (CGSizeEqualToSize(result, CGSizeMake(0.0,0.0)))
	{
		result = CGSizeMake(200.0f, 128.0f);
	}
    return result;
}

- (void)makeOriginalSize;
{
    SVMediaGraphic *container = [self container];
    [container makeOriginalSize];
}

#pragma mark HTML

- (BOOL)shouldWriteHTMLInline; { return NO; }
- (BOOL)canWriteHTMLInline; { return NO; }

@end
