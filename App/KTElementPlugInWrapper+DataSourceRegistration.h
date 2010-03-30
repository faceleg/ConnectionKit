//
//  KTElementPlugInWrapper+DataSourceRegistration.h
//  Marvel
//
//  Created by Mike on 16/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTElementPlugInWrapper.h"
#import "KTDataSourceProtocol.h"



@interface KTElementPlugInWrapper (DataSourceRegistration)

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet;


+ (unsigned)numberOfItemsToProcessDrag:(id <NSDraggingInfo>)draggingInfo;
+ (Class <KTDataSource>)highestPriorityDataSourceForPasteboard:(NSPasteboard *)draggingInfo index:(unsigned)anIndex isCreatingPagelet:(BOOL)isCreatingPagelet;

+ (void)doneProcessingDrag;
@end
