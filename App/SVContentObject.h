//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSExtensibleManagedObject.h"


@class SVPageletBody, KTElementPlugin;


@interface SVContentObject :  KSExtensibleManagedObject  
{
    id  _delegate;
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;



@property (nonatomic, retain) SVPageletBody *container;

@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (id)delegate;
- (KTElementPlugin *)plugin;


#pragma mark HTML
@property(nonatomic, retain, readonly) NSString *elementID;
- (NSString *)archiveHTMLString;    // how to archive a reference to the object in some HTML
- (NSString *)HTMLString;           // for publishing/editing (uses SVHTMLGenerationContext)



@end



