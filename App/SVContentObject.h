//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSExtensibleManagedObject.h"

#import "SVElementPlugIn.h"


#define SVContentObjectWrapNone [NSNumber numberWithInteger:0]
#define SVContentObjectWrapFloatLeft [NSNumber numberWithInteger:1]
#define SVContentObjectWrapFloatRight [NSNumber numberWithInteger:3]
#define SVContentObjectWrapBlockLeft [NSNumber numberWithInteger:4]
#define SVContentObjectWrapBlockCenter [NSNumber numberWithInteger:5]
#define SVContentObjectWrapBlockRight [NSNumber numberWithInteger:6]
//typedef NSNumber SVContentObjectWrap;
#define SVContentObjectWrap NSNumber

#pragma mark -


@class SVPageletBody, KTElementPlugin;


@interface SVContentObject : NSManagedObject


#pragma mark Placement

@property(nonatomic, copy, readonly) SVContentObjectWrap *wrap;

@property(nonatomic, retain) SVPageletBody *container;


#pragma mark HTML
@property(nonatomic, retain, readonly) NSString *elementID;
- (NSString *)archiveHTMLString;    // how to archive a reference to the object in some HTML
- (NSString *)HTMLString;           // for publishing/editing (uses SVHTMLContext)

- (DOMElement *)DOMElementInDocument:(DOMDocument *)document;

@end


