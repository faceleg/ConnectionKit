//
//  SVDownloadSiteItem.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDownloadSiteItem.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "KTPage+Paths.h"
#import "SVPublisher.h"
#import "SVWorkspaceIconProtocol.h"

#import "KSSHA1Stream.h"
#import "NSString+Karelia.h"

#import "KSURLUtilities.h"


@implementation SVDownloadSiteItem

@dynamic media;
- (void)setMedia:(SVMediaRecord *)media
{
    [self willChangeValueForKey:@"media"];
    [self setPrimitiveValue:media forKey:@"media"];
    [self didChangeValueForKey:@"media"];
    
    [self setTitle:[[media preferredFilename] stringByDeletingPathExtension]];
}

- (SVMediaRecord *)mediaRepresentation;
{
    return [self media];
}
+ (NSSet *)keyPathsForValuesAffectingMediaRepresentation
{
    return [NSSet setWithObject:@"media"];
}

#pragma mark Title

- (id)titleBox; { return NSNotApplicableMarker; } // #103991

#pragma mark Thumbnail

// #105408 - in progress
- (NSURL *)addImageRepresentationToContext:(SVHTMLContext *)context
                                      type:(SVThumbnailType)type
                                     width:(NSUInteger)width
                                    height:(NSUInteger)height
                                   options:(SVPageImageRepresentationOptions)options;
{
    if (type == SVThumbnailTypePickFromPage)
    {
        NSString *type = [KSWORKSPACE ks_typeForFilenameExtension:
                          [[[[self media] media] mediaURL] ks_pathExtension]];
        
        if ([type conformsToUTI:(NSString *)kUTTypeImage])
        {
            return [context addImageMedia:[[self media] media]
                                    width:[NSNumber numberWithUnsignedInteger:width]
                                   height:[NSNumber numberWithUnsignedInteger:height]
                                     type:(NSString *)kUTTypePNG
                        preferredFilename:nil
                            scalingSuffix:nil];
        }
        else
        {
            // Derive a URL from the source media that can't accidentally correspond to a real file
            NSURL *URL = [SVWorkspaceIconProtocol URLForWorkspaceIconOfURL:[[[self media] media] mediaURL]];
            
            SVMedia *media = [[SVMedia alloc] initByReferencingURL:URL];
            
            NSURL *result = [context addImageMedia:media
                                             width:[NSNumber numberWithUnsignedInteger:width]
                                            height:[NSNumber numberWithUnsignedInteger:height]
                                              type:(NSString *)kUTTypePNG
                                 preferredFilename:nil
                                     scalingSuffix:nil];
            
            [media release];
            return result;
        }
    }    
    else
    {
        return [super addImageRepresentationToContext:context type:type width:width height:height options:options];
    }
}

- (id)imageRepresentation;
{
    id result = [super imageRepresentation];
    if (!result) 
    {
        result = [KSWORKSPACE iconForFileType:
                  [[[self media] preferredFilename] pathExtension]];
    }
    return result;
}

- (NSString *) imageRepresentationType
{
    NSString *result = ([super imageRepresentation] ?
                     [super imageRepresentationType] :
                     IKImageBrowserNSImageRepresentationType);
    
    return result;
}

#pragma mark Publishing

- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
{
    SVMedia *media = [[self media] media];
    
    NSString *uploadPath = [publishingEngine baseRemotePath];
    uploadPath = [uploadPath stringByAppendingPathComponent:[[self parentPage] uploadPath]];
    uploadPath = [uploadPath stringByDeletingLastPathComponent];
    uploadPath = [uploadPath stringByAppendingPathComponent:[self filename]];
    
    NSData *data = [media mediaData];
    if (data)
    {
        [publishingEngine publishData:data
                               toPath:uploadPath
                     cachedSHA1Digest:nil
                          contentHash:nil
                         mediaRequest:nil
                               object:self];
    }
    else
    {
        [publishingEngine publishContentsOfURL:[media mediaURL]
                                        toPath:uploadPath
                              cachedSHA1Digest:nil
                                        object:self];
    }
}

// For display in the placeholder webview
- (NSURL *)URL
{
    NSURL *result = nil;
    
    NSString *filename = [self filename];
    if (filename)
    {
        result = [NSURL URLWithString:filename
                        relativeToURL:[[self parentPage] URL]];
    }
    
    return result;
}

- (NSString *)filename
{
    return [[self.media preferredFilename] legalizedWebPublishingFilename];
}
- (void)setFilename:(NSString *)filename;
{
    [[self media] setPreferredFilename:filename];
}
+ (NSSet *)keyPathsForValuesAffectingFilename;
{
    return [NSSet setWithObject:@"media.preferredFilename"];
}

- (KTMaster *)master; { return [[self parentPage] master]; }

#pragma mark KTHTMLSourceObject

- (NSString *)HTMLString;
{
    SVMedia *media = [[self media] media];
    
    WebResource *webResource = [media webResource];
    if (webResource)
    {
        CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)[webResource textEncodingName]);
        if (encoding == kCFStringEncodingInvalidId)
        {
            encoding = kCFStringEncodingUTF8;
        }
        
        return [NSString stringWithData:[webResource data] encoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
    }
    
    return [NSString stringWithContentsOfURL:[media mediaURL]
                            fallbackEncoding:NSUTF8StringEncoding
                                       error:NULL];
}

- (void)setHTMLString:(NSString *)html;
{
    /*
    WebResource *webResource = [[WebResource alloc]
                                initWithData:[html dataUsingEncoding:NSUTF8StringEncoding]
                                URL:[NSURL URLWithString:@"x-sandvox://foogly.boo"]
                                MIMEType:[KSWORKSPACE ks_MIMETypeForType:(NSString *)kUTTypePlainText]
                                textEncodingName:<#(NSString *)textEncodingName#> frameName:<#(NSString *)frameName#>]*/
    
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:
                                       @"x-sandvox-fake-url:///%@.%@",
                                       [data ks_SHA1DigestString],
                                       [[self filename] pathExtension]]];
    
    SVMedia *media = [[SVMedia alloc] initWithData:data URL:url];
    [media setPreferredFilename:[self filename]];
    
    SVMediaRecord *record = [SVMediaRecord mediaRecordWithMedia:media
                                                     entityName:@"FileMedia"
                                 insertIntoManagedObjectContext:[self managedObjectContext]];
    
    [self replaceMedia:record forKeyPath:@"media"];
    [media release];
}

// No contentType stored for these.  If it's an HTML page, it's encoded in the page itself.
- (void)setContentType:(NSString *)contentType; { }

- (NSString *)contentType;
{
	if ([self media])
	{
		return [[self media] typeOfFile];
	}
	return (NSString *)kUTTypeData;
}

- (NSData *)lastValidMarkupDigest; { return [self valueForUndefinedKey:@"lastValidMarkupDigest"]; }
- (void)setLastValidMarkupDigest:(NSData *)digest;
{
    [self setValue:digest forUndefinedKey:@"lastValidMarkupDigest"]; 
}

- (NSNumber *)shouldPreviewWhenEditing; { return NSBOOL(YES); }
- (void)setShouldPreviewWhenEditing:(NSNumber *)preview; { }

- (BOOL)shouldValidateAsFragment; { return NO; }

- (BOOL)usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    return ([key isEqualToString:@"docType"] || [key isEqualToString:@"lastValidMarkupDigest"] ?
            YES :
            [super usesExtensiblePropertiesForUndefinedKey:key]);
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Reference the file somehow. Same logic as SVMediaGraphic
    NSURL *url = [[self media] fileURL];
    if (url)
    {
        [propertyList setObject:[url absoluteString] forKey:@"fileURL"];
    }
    else
    {
        NSData *data = [[[self media] media] mediaData];
        [propertyList setValue:data forKey:@"fileContents"];
    }
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    NSString *urlString = [propertyList objectForKey:@"fileURL"];
    if (urlString)
    {
        NSURL *url = [NSURL URLWithString:urlString];
        SVMedia *media = [[SVMedia alloc] initByReferencingURL:url];
        
        SVMediaRecord *record = [SVMediaRecord mediaRecordWithMedia:media entityName:@"FileMedia" insertIntoManagedObjectContext:[self managedObjectContext]];
        
        [self setMedia:record];
        [media release];
    }
    
    [super awakeFromPropertyList:propertyList];
}

@end
