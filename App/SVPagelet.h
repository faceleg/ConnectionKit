//
//  SVPagelet.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVPageletContent;
@class SVSidebar;

@interface SVPagelet :  NSManagedObject  
{
}

@property(nonatomic, retain) NSString * titleHTMLString;
@property(nonatomic, retain) SVSidebar * sidebar;
@property(nonatomic, retain, readonly) SVPageletContent *content;

@end



