//
//  SVPublishingHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishingHTMLContext.h"

#import "KTHostProperties.h"
#import "SVImageMedia.h"
#import "KTPage.h"
#import "SVPublisher.h"
#import "KTSite.h"

#import "NSData+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "KSPathUtilities.h"


@implementation SVPublishingHTMLContext

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher;
{    
    self = [self init];
    
    _path = [path copy];
    _publisher = [publisher retain];
    
    return self;
}

- (void)close;
{
    // Generate HTML data
    NSString *html = [[self outputStringWriter] string];
	if (html)
    {
        NSStringEncoding encoding = [self encoding];
        
        NSData *pageData = [[html unicodeNormalizedString] dataUsingEncoding:encoding
                                                        allowLossyConversion:YES];
        OBASSERT(pageData);
        
        
        // Give subclasses a chance to ignore the upload
        id <SVPublisher> publishingEngine = _publisher;
        KTPage *page = [self page];
        NSString *fullUploadPath = [[publishingEngine baseRemotePath]
                                    stringByAppendingPathComponent:_path];
        
        
        // Generate data digest. It has to ignore the app version string
        NSString *versionString = [NSString stringWithFormat:@"<meta name=\"generator\" content=\"%@\" />",
                                   [[page site] appNameVersion]];
        NSString *versionFreeHTML = [html stringByReplacing:versionString with:@"<meta name=\"generator\" content=\"Sandvox\" />"];
        NSData *digest = [[versionFreeHTML dataUsingEncoding:encoding allowLossyConversion:YES] SHA1Digest];
        
        
        
        // Upload page data. Store the page and its digest with the record for processing later
        if (fullUploadPath)
        {
            [publishingEngine publishData:pageData
                                   toPath:fullUploadPath
                         cachedSHA1Digest:nil
                              contentHash:digest
                                   object:page];
        }
    }
    
    
    // Tidy up
    [super close];
    //[_publishingEngine release]; _publishingEngine = nil;     Messes up media gathering
    [_path release]; _path = nil;
}

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    NSString *path = [_publisher publishMedia:media];
    
    NSString *basePath = [_publisher baseRemotePath];
    NSString *relPath = [path ks_pathRelativeToDirectory:basePath];
    
    if (relPath)
    {
        NSURL *result = [NSURL URLWithString:relPath relativeToURL:[self baseURL]];
        return result;
    }
    
    return nil;
}

- (NSURL *)addImageMedia:(id <SVMedia>)media
                   width:(NSNumber *)width
                  height:(NSNumber *)height
                    type:(NSString *)type;
{
    // When scaling an image, need full suite of parameters
    if (width || height)
    {
        OBPRECONDITION(width);
        OBPRECONDITION(height);
        OBPRECONDITION(type);
    }
    
    
    // If the width and height match the original size, then keep that way
    if (CGSizeEqualToSize(IMBImageItemGetSize((id)media),
                          CGSizeMake([width floatValue], [height floatValue])))
    {
        width = nil;
        height = nil;
    }
    
    id <SVMedia> scaledMedia = [[SVImageMedia alloc] initWithSourceMedia:media
                                                                   width:width
                                                                  height:height
                                                                    type:type];
    
    NSURL *result = [self addMedia:scaledMedia];
    [scaledMedia release];
    
    return result;
}

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    [super addResourceWithURL:resourceURL];
    [_publisher publishResourceAtURL:resourceURL];
    
    return [[[[self page] site] hostProperties] URLForResourceFile:[resourceURL ks_lastPathComponent]];
}

- (NSURL *)addGraphicalTextData:(NSData *)imageData idName:(NSString *)idName;
{
    NSURL *result = [super addGraphicalTextData:imageData idName:idName];
    
    NSString *designPath = [_publisher designDirectoryPath];
    NSString *uploadPath = [designPath stringByAppendingPathComponent:[result ks_lastPathComponent]];
    
    [_publisher publishData:imageData toPath:uploadPath];
    
    return result;
}

- (void)addCSSString:(NSString *)css;
{
    [super addCSSString:css];   // should have no effect
    
    // Append to main.css
    [_publisher addCSSString:css];
}

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    [super addCSSWithURL:cssURL];   // should have no effect
    
    // Append to main.css
    [_publisher addCSSWithURL:cssURL];
}

#pragma mark Raw Writing

- (void)writeString:(NSString *)string;
{
    [super writeString:string];
    
    // Run event loop to avoid stalling the GUI too long
    NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast] inMode:NSDefaultRunLoopMode dequeue:YES];
    if (event)
    {
        [NSApp sendEvent:event];
    }
}

#pragma mark Page

- (void)writeDocumentWithPage:(KTPage *)page;
{
    [self setBaseURL:[page URL]];
    [super writeDocumentWithPage:page];
}

@end
