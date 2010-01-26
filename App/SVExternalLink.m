// 
//  SVExternalLink.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVExternalLink.h"

#import "SVURLPreviewViewController.h"

#import "NSURL+Karelia.h"


@implementation SVExternalLink 

@dynamic openInNewWindow;

@dynamic linkURLString;

- (NSURL *)URL
{
    NSString *urlString = [self linkURLString];
    NSURL *result = nil;
    if (urlString)
    {
        result = [NSURL URLWithString:urlString];
    }
    
    return result;
}

- (void)setURL:(NSURL *)url
{
    [self setLinkURLString:[url absoluteString]];
    
    // Derive title from URL
    NSString *title = [url guessedTitle];
    [self setTitle:title];
}

+ (NSSet *)keyPathsForValuesAffectingURL
{
    return [NSSet setWithObject:@"linkURLString"];
}

- (NSString *)fileName
{
    return [[[self URL] lastPathComponent] stringByDeletingPathExtension];
}

- (SVExternalLink *)externalLinkRepresentation
{
	return self;
}

- (BOOL)canPreview
{
	return (nil != [self URL]);		// Maybe be even smarter about having a real URL?
}

@end
