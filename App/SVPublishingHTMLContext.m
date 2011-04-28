//
//  SVPublishingHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPublishingHTMLContext.h"

#import "KTHostProperties.h"
#import "SVHTMLTemplateParser.h"
#import "KTMaster.h"
#import "SVMedia.h"
#import "SVMediaRequest.h"
#import "KTPage+Paths.h"
#import "SVPublisher.h"
#import "KTPublishingEngine.h"
#import "KTSite.h"
#import "SVTemplate.h"

#import "KSSHA1Stream.h"
#import "NSString+Karelia.h"

#import "KSOutputStreamWriter.h"
#import "KSURLUtilities.h"
#import "KSPathUtilities.h"

#import <Connection/Connection.h>


@implementation SVPublishingHTMLContext

#pragma mark Lifecycle

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher;
{    
    // If there's no destination, don't bother storing the HTML!
    self = (path ? [self init] : [self initWithOutputStringWriter:nil]);
    
    _path = [path copy];
    _publisher = [publisher retain];
    
    return self;
}

- (void)close;
{
    // Publish HTML if complete
    if (![self didAddMediaWithoutPath] ||
        [(KTPublishingEngine *)_publisher status] >= KTPublishingEngineStatusParsing)
    {
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
            
            
            // Upload page data. Store the page and its digest with the record for processing later
            if (fullUploadPath)
            {
                [_contentHashStream close];
                
                [publishingEngine publishData:pageData
                                       toPath:fullUploadPath
                             cachedSHA1Digest:nil
                                  contentHash:[_contentHashStream SHA1Digest]
                                       object:page];
            }
        }
    }
    
    
    // Tidy up
    [super close];
    
    //[_publishingEngine release]; _publishingEngine = nil;     Messes up media gathering
    [_contentHashDataOutput release]; _contentHashDataOutput = nil;
    [_contentHashStream release]; _contentHashStream = nil;
    [_path release]; _path = nil;
}

#pragma mark Media

- (NSURL *)addMedia:(SVMedia *)media;
{
    SVMediaRequest *request = [[SVMediaRequest alloc] initWithMedia:media];
    NSURL *result = [self addMediaWithRequest:request];
    [request release];
    return result;
}

- (NSURL *)addImageMedia:(SVMedia *)media
                   width:(NSNumber *)width
                  height:(NSNumber *)height
                    type:(NSString *)type
       preferredFilename:(NSString *)preferredFilename;
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
    
    NSString *path = nil;
    if (preferredFilename)
    {
        path = [[[[media preferredUploadPath]
                  stringByDeletingLastPathComponent]
                 stringByAppendingPathComponent:preferredFilename]
                stringByStandardizingHTTPPath];
    }
    
    SVMediaRequest *request = [[SVMediaRequest alloc] initWithMedia:media
                                                              width:width
                                                             height:height
                                                               type:type
                                                preferredUploadPath:path];
    
    NSURL *result = [self addMediaWithRequest:request];
    [request release];
    
    return result;
}

- (NSURL *)addMediaWithRequest:(SVMediaRequest *)request;
{
    NSString *mediaPath = [_publisher publishMediaWithRequest:request];
    if (!mediaPath) _didAddMediaWithoutPath++;
    
    KTPage *page = [self page];
    if (page)
    {
        NSString *pagePath = [[_publisher baseRemotePath] stringByAppendingPathComponent:[page uploadPath]];
        
        NSString *relPath = [mediaPath ks_pathRelativeToDirectory:[pagePath stringByDeletingLastPathComponent]];
        
        if (relPath)
        {
            // Can't use -baseURL here as it may differ to [page URL] (e.g. archive pages) #98791
            NSURL *result = [NSURL URLWithString:relPath relativeToURL:[page URL]];
            return result;
        }
    }
    else
    {
        // e.g. RSS
        if (mediaPath)
        {
            NSString *mediaPathRelativeToBase = [mediaPath ks_pathRelativeToDirectory:[_publisher baseRemotePath]];
            
            NSURL *result = [NSURL URLWithString:mediaPathRelativeToBase
                                   relativeToURL:[[[_publisher site] rootPage] URL]];
            
            return result;
        }
    }
    
    
    return nil;
}

- (BOOL)didAddMediaWithoutPath; { return _didAddMediaWithoutPath; }

#pragma mark Resources

- (NSURL *)addResourceAtURL:(NSURL *)fileURL destination:(NSString *)uploadPath options:(NSUInteger)options;
{
    if ([uploadPath isEqualToString:SVDestinationMainCSS])
    {
        // Append to main.css
        [_publisher addCSSWithURL:fileURL];
        return [super addResourceAtURL:fileURL destination:uploadPath options:options];
    }
    
    
    
    NSURL *result = [super addResourceAtURL:fileURL destination:uploadPath options:options];
    NSURL *siteURL = [[[_publisher site] hostProperties] siteURL];
    NSURL *uploadURL = [result ks_URLRelativeToURL:siteURL];
    
    // Only publish if figured a decent URL for it
    if ([uploadURL ks_isSubpathOfURL:siteURL])
    {
        NSString *uploadPath = [[_publisher baseRemotePath]
                                stringByAppendingPathComponent:[uploadURL relativeString]];
        
        [_publisher publishContentsOfURL:fileURL toPath:uploadPath];
    }
    
    return result;
}

- (void)addJavascriptResourceWithTemplateAtURL:(NSURL *)templateURL
                                        object:(id)object;
{
    // Run through template parser
    NSString *parsedResource = [self parseTemplateAtURL:templateURL object:object];
    if (parsedResource)
    {        
        // Figure path
        NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
        NSString *resourcesDirectoryPath = [[_publisher baseRemotePath] stringByAppendingPathComponent:resourcesDirectoryName];
        NSString *resourceRemotePath = [resourcesDirectoryPath stringByAppendingPathComponent:[templateURL ks_lastPathComponent]];
        
        
        // Publish
        [_publisher publishData:[parsedResource dataUsingEncoding:NSUTF8StringEncoding]
                         toPath:resourceRemotePath];
    }
    
    [super addJavascriptResourceWithTemplateAtURL:templateURL object:object];
}

- (NSURL *)addGraphicalTextData:(NSData *)imageData idName:(NSString *)idName;
{
    NSURL *result = [super addGraphicalTextData:imageData idName:idName];
    
    NSString *designPath = [_publisher designDirectoryPath];
    NSString *uploadPath = [designPath stringByAppendingPathComponent:[result ks_lastPathComponent]];
    
    [_publisher publishData:imageData toPath:uploadPath];
    
    return result;
}

- (NSURL *)addCSSString:(NSString *)css;
{
    // Append to main.css
    [_publisher addCSSString:css];
    
    return [super addCSSString:css];
}

#pragma mark Change Tracking

- (void)disableChangeTracking; { _disableChangeTracking++; }

- (void)enableChangeTracking; { _disableChangeTracking--; }

- (BOOL)isChangeTrackingEnabled; { return _disableChangeTracking == 0; }

#pragma mark Raw Writing

- (void)writeString:(NSString *)string;
{
    [super writeString:string];
    
    if ([self isChangeTrackingEnabled])
    {
        if (!_contentHashDataOutput && !_contentHashStream)
        {
            _contentHashStream = [[KSSHA1Stream alloc] init];
            
            _contentHashDataOutput = [[KSOutputStreamWriter alloc] initWithOutputStream:_contentHashStream
                                                                               encoding:[self encoding]];
        }
        
        [_contentHashDataOutput writeString:string];
    }
    
    
    // Run event loop to avoid stalling the GUI too long
    if (!_disableRunningEventLoop)
    {
        NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast] inMode:NSDefaultRunLoopMode dequeue:YES];
        if (event)
        {
            [NSApp sendEvent:event];
        }
    }
}

- (void)writeGraphic:(id <SVGraphic>)graphic;
{
    // Disable running the event loop while writing a graphic, since it might mess with the graphic's state. #111825
    _disableRunningEventLoop++;
    [super writeGraphic:graphic];
    _disableRunningEventLoop--;
}

#pragma mark Page

- (void)writeDocumentWithPage:(KTPage *)page;
{
    [self setBaseURL:[page URL]];
    [super writeDocumentWithPage:page];
}

@end
