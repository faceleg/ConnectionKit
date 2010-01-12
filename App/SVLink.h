//
//  SVLink.h
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Immutable object, rather like NSFont, that encapsulates a link.


#import <Cocoa/Cocoa.h>


@class KTAbstractPage;


@interface SVLink : NSObject <NSCopying>
{
  @private
    NSString        *_URLString;
    KTAbstractPage  *_page;
}

#pragma mark Creating a link
- (id)initWithURLString:(NSString *)urlString;
- (id)initWithPage:(KTAbstractPage *)page;


#pragma mark Link Properties
@property(nonatomic, copy, readonly) NSString *URLString;   // should always be non-nil
@property(nonatomic, retain, readonly) KTAbstractPage *page;// non-nil only if created from a page

- (NSString *)targetDescription;    // normally anchor's href, but for page targets, the page title

@end
