//
//  SVLinkManager.h
//  Sandvox
//
//  Created by Mike on 12/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVUnmodeledLink;


@interface SVLinkManager : NSObject
{
  @private
    SVUnmodeledLink *_selectedLink;
    BOOL            _editable;
}

+ (SVLinkManager *)sharedLinkManager;


#pragma mark Selected Link

// Any UI object working with links should send SVLinkManager a -setSelectedLink:editable: message each time its selection changes
- (void)setSelectedLink:(SVUnmodeledLink *)link editable:(BOOL)editable;
@property(nonatomic, retain, readonly) SVUnmodeledLink *selectedLink;
@property(nonatomic, readonly, getter=isEditable) BOOL editable;


@end
