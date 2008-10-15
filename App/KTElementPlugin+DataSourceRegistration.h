//
//  KTElementPlugin+DataSourceRegistration.h
//  Marvel
//
//  Created by Mike on 16/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTElementPlugin.h"
#import "KTDataSource.h"



@interface KTElementPlugin (DataSourceRegistration)

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet;


+ (unsigned)numberOfItemsToProcessDrag:(id <NSDraggingInfo>)draggingInfo;
+ (Class <KTDataSource>)highestPriorityDataSourceForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned)anIndex isCreatingPagelet:(BOOL)isCreatingPagelet;

+ (void)doneProcessingDrag;
@end
