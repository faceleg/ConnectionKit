//
//  SVUnmodeledLink.h
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  A thin wrapper around SVHTMLAnchorElement for the benfit of the Inspector


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface SVUnmodeledLink : NSObject
{
  @private
    DOMHTMLAnchorElement    *_anchor;
    NSManagedObjectContext  *_moc;
}

- (id)initWithAnchorElement:(DOMHTMLAnchorElement *)anchor;
@property(nonatomic, retain, readonly) DOMHTMLAnchorElement *anchorElement;

@property(nonatomic, readonly, getter=isLocalLink) BOOL localLink;

- (NSString *)targetDescription;    // normally anchor's href, but for page targets, the page title
- (void)setTargetDescription:(NSString *)desc;   // sets anchor's href

@property(nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end
