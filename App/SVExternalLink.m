// 
//  SVExternalLink.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVExternalLink.h"

#import "SVHTMLContext.h"
#import "SVMedia.h"
#import "SVURLPreviewViewController.h"
#import "SVWebEditingURL.h"

#import "NSImage+KTExtensions.h"

#import "NSURL+Karelia.h"
#import "KSURLUtilities.h"


@implementation SVExternalLink 

@dynamic linkURLString;

- (NSURL *)URL
{
    NSURL *result = nil;
    
    if ([self linkURLString]) result = [NSURL URLWithString:[self linkURLString]];
    
    return result;
}

- (void)setURL:(NSURL *)url
{
    [self setLinkURLString:[url absoluteString]];
    
	if (url)
	{
		// Derive title from URL
		NSString *title = [url guessedTitle];
		[self setTitle:title];
	}
	else
	{
		[self setTitle:NSLocalizedString(@"Untitled", "placeholder text")];
	}
}

+ (NSSet *)keyPathsForValuesAffectingURL
{
    return [NSSet setWithObject:@"linkURLString"];
}

- (NSString *)filename; { return nil; }

- (NSString *)fileName
{
    return [[[self URL] ks_lastPathComponent] stringByDeletingPathExtension];
}

- (SVExternalLink *)externalLinkRepresentation
{
	return self;
}

- (BOOL)canPreview
{
	return (nil != [self URL]);		// Maybe be even smarter about having a real URL?
}

#pragma mark Title

- (id)titleBox; { return NSNotApplicableMarker; } // #103991

#pragma mark Thumbnail

- (BOOL)writeImageRepresentation:(SVHTMLContext *)context
                       type:(SVThumbnailType)type
                      width:(NSUInteger)width
                     height:(NSUInteger)height
                    options:(SVPageImageRepresentationOptions)options;
{
    if (type == SVThumbnailTypePickFromPage)
    {
        if (!(options & SVPageImageRepresentationDryRun))
        {
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType:@"webloc"];
            NSData *png = [icon PNGRepresentation];
            
            SVMedia *media = [[SVMedia alloc] initWithData:png URL:[NSURL URLWithString:@"x-sandvox:///webloc.png"]];
            
            [context writeImageWithSourceMedia:media
                                           alt:@""
                                         width:[NSNumber numberWithUnsignedInteger:width]
                                        height:[NSNumber numberWithUnsignedInteger:height]
                                          type:(NSString *)kUTTypePNG
                             preferredFilename:nil];
            
            [media release];
        }
        
        return YES;
    }
    else
    {
        return [super writeImageRepresentation:context type:type width:width height:height options:options];
    }
}

#pragma mark Other properties

- (KTMaster *)master; { return [[self parentPage] master]; }

@end
