//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSExtensibleManagedObject.h"


@class SVPageletBody, KTElementPlugin, SVElementPlugIn;


@interface SVContentObject :  KSExtensibleManagedObject  
{
    id  _plugIn;
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;



@property (nonatomic, retain) SVPageletBody *container;

@property(nonatomic, retain, readonly) SVElementPlugIn *plugIn;
@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (KTElementPlugin *)plugin;


#pragma mark HTML
@property(nonatomic, retain, readonly) NSString *elementID;
- (NSString *)archiveHTMLString;    // how to archive a reference to the object in some HTML
- (NSString *)HTMLString;           // for publishing/editing (uses SVHTMLGenerationContext)



@end



