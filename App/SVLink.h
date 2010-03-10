//
//  SVLink.h
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Immutable object, rather like NSFont, that encapsulates a link.
//  It's actually fairly close to PSLink in many ways – can we match them a bit?


#import <Cocoa/Cocoa.h>


typedef enum {
    SVLinkToPage = 1,
    SVLinkToRSSFeed,
    SVLinkToFullSizeImage = 8,
    SVLinkExternal = 10,
} SVLinkType;


@class KTPage, SVHTMLContext;


@interface SVLink : NSObject <NSCopying>
{
  @private
    SVLinkType  _type;
    NSString    *_URLString;
    KTPage      *_page;
    BOOL        _openInNewWindow;
}

#pragma mark Creating a link
- (id)initWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
- (id)initWithPage:(KTPage *)page openInNewWindow:(BOOL)openInNewWindow;
- (id)initLinkToFullSizeImageOpensInNewWindow:(BOOL)openInNewWindow;


#pragma mark Link Properties
@property(nonatomic, readonly) SVLinkType linkType;
@property(nonatomic, copy, readonly) NSString *URLString;   // should always be non-nil
@property(nonatomic, retain, readonly) KTPage *page;// non-nil only if created from a page
@property(nonatomic, readonly) BOOL openInNewWindow;

- (NSString *)targetDescription;    // normally anchor's href, but for page targets, the page title


#pragma mark Deriving a new Link


#pragma mark HTML
- (void)writeStartTagToContext:(SVHTMLContext *)context;


@end
