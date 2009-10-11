//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVPageletBody;

@interface SVContentObject :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * elementID;
@property (nonatomic, retain) SVPageletBody * container;

@end



