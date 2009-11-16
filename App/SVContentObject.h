//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSExtensibleManagedObject.h"

#import "SVElementPlugIn.h"


@class SVPageletBody, KTElementPlugin;


@interface SVContentObject : NSManagedObject
{
    id  _plugIn;
}



@property (nonatomic, retain) SVPageletBody *container;


#pragma mark HTML
@property(nonatomic, retain, readonly) NSString *elementID;
- (NSString *)archiveHTMLString;    // how to archive a reference to the object in some HTML
- (NSString *)HTMLString;           // for publishing/editing (uses SVHTMLContext)

- (DOMElement *)DOMElementInDocument:(DOMDocument *)document;

@end



