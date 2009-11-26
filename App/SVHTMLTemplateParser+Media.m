//
//  SVHTMLTemplateParser+Media.m
//  Marvel
//
//  Created by Mike on 08/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVHTMLTemplateParser+Private.h"

#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "KTMaster+Internal.h"
#import "KTMediaContainer.h"
#import "KTMediaFile+Internal.h"
#import "KTPage+Internal.h"

#import "NSURL+Karelia.h"


@implementation SVHTMLTemplateParser (Media)

- (NSString *)mediainfoWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)scanner
{
	NSString *result = @"";
	
	// Build the parameters dictionary
	NSDictionary *parameters = [SVHTMLTemplateParser parametersDictionaryWithString:inRestOfTag];
	
	// Which MediaContainer is requested?
	NSString *mediaKeyPath = [parameters objectForKey:@"media"];
	KTMediaContainer *media = [[self cache] valueForKeyPath:mediaKeyPath];
	
	if (media)
	{
		// Scaling setting
		NSDictionary *scalingProperties = nil;
		if ([parameters objectForKey:@"sizeName"])
		{
			NSString *settingsName = [parameters objectForKey:@"sizeName"];
			scalingProperties = [[[[[SVHTMLContext currentContext] currentPage] master] design] imageScalingPropertiesForUse:settingsName];
		}
		else if ([parameters objectForKey:@"sizeToFit"])
		{
			NSValue *size = [[self cache] valueForKeyPath:[parameters objectForKey:@"sizeToFit"]];
			if (size)
			{
				KTImageScalingSettings *scalingSettings = [KTImageScalingSettings settingsWithBehavior:KTScaleToSize size:[size sizeValue]];
				scalingProperties = [NSDictionary dictionaryWithObject:scalingSettings forKey:@"scalingBehavior"];
			}
		}
		
		
		
		result = [self info:[parameters objectForKey:@"info"]
				   forMedia:media
			scalingProperties:scalingProperties];
		
		if (!result) result = @"";
	}
	
	
	// In the worst case, an empty string should be returned.
    OBASSERTSTRING(result, ([NSString stringWithFormat:@"[[mediainfo %@]] is returning nil", inRestOfTag]));    
	return result;
}

- (NSString *)info:(NSString *)infoString forMedia:(KTMediaContainer *)media scalingProperties:(NSDictionary *)scalingProperties
{
	OBPRECONDITION(infoString);
	OBPRECONDITION(media);
	
	
	NSString *result = nil;
	
	// What information is desired?
	KTMediaFile *mediaFile = [media file];
	if (mediaFile)
	{
		if ([infoString isEqualToString:@"path"])
		{
			result = [self pathToMedia:mediaFile scalingProperties:scalingProperties];
		}
		else if ([infoString isEqualToString:@"width"])
		{
			result = [self widthStringForMediaFile:mediaFile scalingProperties:scalingProperties];
		}
		else if ([infoString isEqualToString:@"height"])
		{
			result = [self heightStringForMediaFile:mediaFile scalingProperties:scalingProperties];
		}
		else if ([infoString isEqualToString:@"MIMEType"])
		{
			NSString *MIMEType = [NSString MIMETypeForUTI:[mediaFile fileType]];
			
			// Some MIME types are not known to the system. If so, fall back to raw data
			if (!MIMEType || [MIMEType isEqualToString:@""])
			{
				MIMEType = @"application/octet-stream";
			}
			
			result = [MIMEType stringByEscapingHTMLEntities];
		}
		else if ([infoString isEqualToString:@"dataLength"])
		{
			NSString *path = [mediaFile currentPath];
			if (path)
			{
				NSDictionary *fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO];
				NSString *fileSize = [[fileAttributes objectForKey:NSFileSize] stringValue];
				if (fileSize) result = fileSize;
			}
		}
	}
	
	
	return result;
}

- (NSString *)pathToMedia:(KTMediaFile *)media scalingProperties:(NSDictionary *)scalingProps
{
	switch ([[SVHTMLContext currentContext] generationPurpose])
	{
		case kGeneratingPreview:
			return [[media URLForImageScalingProperties:scalingProps] absoluteString];
			break;
			
		case kGeneratingQuickLookPreview:
			return [media quickLookPseudoTag];
			break;
			
		default:
		{
			KTMediaFileUpload *upload = [media uploadForScalingProperties:scalingProps];
			
			// The delegate may want to know
			[self didEncounterMediaFile:media upload:upload];
			
			return [[upload URL] stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
			break;
		}
	}
}

- (NSString *)widthStringForMediaFile:(KTMediaFile *)mediaFile scalingProperties:(NSDictionary *)scalingProps
{
    NSString *result = nil;
	
	
	// Build canonical scaling props
	if (scalingProps) scalingProps = [mediaFile canonicalImageScalingPropertiesForProperties:scalingProps];
	
	
	KTImageScalingSettings *scalingSettings = [scalingProps objectForKey:@"scalingBehavior"];
	if (scalingProps && [scalingSettings behavior] == KTStretchToSize)
	{
		result = [[NSNumber numberWithFloat:([scalingSettings size].width)] stringValue];
	}
	else
	{
		[mediaFile cacheImageDimensionsIfNeeded];
		
		NSNumber *width = [mediaFile valueForKey:@"width"];
		result = (width) ? [width stringValue] : nil;
	}
		
	return result;
}

- (NSString *)heightStringForMediaFile:(KTMediaFile *)mediaFile scalingProperties:(NSDictionary *)scalingProps
{
    NSString *result = nil;
	
	
	// Build canonical scaling props
	if (scalingProps) scalingProps = [mediaFile canonicalImageScalingPropertiesForProperties:scalingProps];
	
	
	KTImageScalingSettings *scalingSettings = [scalingProps objectForKey:@"scalingBehavior"];
	if (scalingProps && [scalingSettings behavior] == KTStretchToSize)
	{
		result = [[NSNumber numberWithFloat:([scalingSettings size].height)] stringValue];
	}
	else
	{
		[mediaFile cacheImageDimensionsIfNeeded];
		
		NSNumber *height = [mediaFile valueForKey:@"height"];
		result = (height) ? [height stringValue] : nil;
	}
	
	return result;
}

@end
