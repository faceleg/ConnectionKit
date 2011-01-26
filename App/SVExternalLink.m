// 
//  SVExternalLink.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVExternalLink.h"

#import "SVURLPreviewViewController.h"
#import "SVWebEditingURL.h"

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

#pragma mark Other properties

- (KTMaster *)master; { return [[self parentPage] master]; }

@end
