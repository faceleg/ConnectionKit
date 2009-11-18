//
//  SVBodyElement.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVPageletBody;

@interface SVBodyElement :  NSManagedObject  
{
}

@property (nonatomic, retain) SVPageletBody * body;
@property (nonatomic, retain) SVBodyElement * previousElement;
@property (nonatomic, retain) SVBodyElement * nextElement;

@end



