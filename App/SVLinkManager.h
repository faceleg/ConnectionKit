//
//  SVLinkManager.h
//  Sandvox
//
//  Created by Mike on 12/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVLink;


@interface SVLinkManager : NSObject
{
  @private
    SVLink *_selectedLink;
    BOOL            _editable;
}

+ (SVLinkManager *)sharedLinkManager;


#pragma mark Selected Link

// Any UI object working with links should send SVLinkManager a -setSelectedLink:editable: message each time its selection changes
- (void)setSelectedLink:(SVLink *)link editable:(BOOL)editable;
@property(nonatomic, retain, readonly) SVLink *selectedLink;
@property(nonatomic, readonly, getter=isEditable) BOOL editable;


#pragma mark Modifying the Link
- (void)modifyLinkTo:(SVLink *)link;    // sends -changeLink: up the responder chain


#pragma mark Link Inspector
- (IBAction)orderFrontLinkPanel:(id)sender; // Sets the current Inspector to view links
- (SVLink *)guessLink;  // looks at the user's workspace to guess what they want. Nil if no match is found


@end


// When changing the link, this message is sent up the responder chain. A suitable object should handle it by asking the sender for the appropriate link properties. For now, this is best done by sending it a -linkDestinationURLString: method.
@interface NSObject (SVLinkManagerResponderMethod)
- (void)changeLink:(SVLinkManager *)sender;
@end