//
//  SVLink.h
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Immutable object, rather like NSFont, that encapsulates a link.
//  It's actually fairly close to PSLink in many ways – can we match them a bit?


#import <Cocoa/Cocoa.h>


typedef enum {
    SVLinkToPage = 1,
    SVLinkToRSSFeed,
    SVLinkToFullSizeImage = 8,
    SVLinkExternal = 10,
    SVLinkEmail
} SVLinkType;


@class SVSiteItem, SVHTMLContext, SVImage;


@interface SVLink : NSObject <NSCopying, NSCoding>  // NSCoding DOESN'T apply to page links
{
  @private
    SVLinkType  _type;
    NSString    *_URLString;
    SVSiteItem  *_page;
    BOOL        _openInNewWindow;
}

#pragma mark Creating a link
+ (id)linkWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
+ (id)linkWithSiteItem:(SVSiteItem *)item openInNewWindow:(BOOL)openInNewWindow;
- (id)initWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
- (id)initWithPage:(SVSiteItem *)page openInNewWindow:(BOOL)openInNewWindow;
- (id)initLinkToFullSizeImageOpensInNewWindow:(BOOL)openInNewWindow;


#pragma mark Link Properties
@property(nonatomic, readonly) SVLinkType linkType;
@property(nonatomic, copy, readonly) NSString *URLString;   // should always be non-nil
@property(nonatomic, retain, readonly) SVSiteItem *page;// non-nil only if created from a page
@property(nonatomic, readonly) BOOL openInNewWindow;

- (NSString *)targetDescription;    // normally anchor's href, but for page targets, the page title


#pragma mark Deriving a new Link
- (SVLink *)linkWithOpensInNewWindow:(BOOL)openInNewWindow;


#pragma mark HTML
- (void)writeStartTagToContext:(SVHTMLContext *)context image:(SVImage *)image;
- (DOMElement *)createDOMElementInDocument:(DOMDocument *)document;
- (NSString *)hrefInContext:(SVHTMLContext *)context image:(SVImage *)image;


@end
