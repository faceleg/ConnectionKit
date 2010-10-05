//
//  SVMediaPlugIn.m
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaPlugIn.h"

#import "SVMediaRecord.h"

#import "NSString+Karelia.h"
#import "KSURLUtilities.h"


@implementation SVMediaPlugIn

- (void)awakeFromPasteboardContents:(id)contents ofType:(NSString *)type;
{
}

#pragma mark Properties

- (SVMediaRecord *)media; { return [[self container] media]; }
- (SVMediaRecord *)posterFrame; { return [[self container] posterFrame]; }
- (NSURL *)externalSourceURL; { return [[self container] externalSourceURL]; }

- (void)didSetSource; { }

- (BOOL)validateTypeToPublish:(NSString **)type error:(NSError **)errror;
{
    return YES;
}

+ (NSArray *)allowedFileTypes; { return nil; }

#pragma mark Metrics

+ (BOOL)isExplicitlySized; { return YES; }

- (CGSize)originalSize;
{
    CGSize result = CGSizeZero;
    
    SVMediaRecord *media = [self media];
    if (media)
	{
		SVMediaGraphic *container = [self container];
        
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

#pragma mark RSS Enclosures

// THIS CODE IS DUPLICATED BETWEEN AUDIO AND VIDEO

- (NSURL *)downloadedURL;   // where it currently resides on disk
{
	NSURL *mediaURL = nil;
	SVMediaRecord *media = [self media];
	
    if (media)
    {
		mediaURL = [media mediaURL];
	}
	else
	{
		mediaURL = [self externalSourceURL];
	}
	return mediaURL;
}

- (long long)length;
{
	long long result = 0;
	SVMediaRecord *media = [self media];
	
    if (media)
    {
		NSData *mediaData = [media mediaData];
		result = [mediaData length];
	}
	return result;
}

- (NSString *)MIMEType;
{
	NSString *type = [[self media] typeOfFile];
    if (!type)
    {
        type = [NSString UTIForFilenameExtension:[[self externalSourceURL] ks_pathExtension]];
    }
    
    NSString *result = (type ? [NSString MIMETypeForUTI:type] : nil);
	return result;
}

#pragma mark HTML

- (BOOL)shouldWriteHTMLInline; { return NO; }
- (BOOL)canWriteHTMLInline; { return NO; }

@end
