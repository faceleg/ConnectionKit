//
//  SVFlash.h
//  Sandvox
//
//  Created by Dan Wood on 9/9/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVMediaGraphic.h"
#import <QTKit/QTKit.h>

@class SVMediaRecord;



@interface SVFlash : SVMediaGraphic
{
	
}
+ (SVFlash *)insertNewFlashInManagedObjectContext:(NSManagedObjectContext *)context;



@property(nonatomic, copy) NSNumber *autoplay;
@property(nonatomic, copy) NSNumber *showMenu;	// BOOLs
@property(nonatomic, copy) NSNumber *loop;
@property(nonatomic, copy) NSString *flashvars;	// http://kb2.adobe.com/cps/164/tn_16417.html

@end



