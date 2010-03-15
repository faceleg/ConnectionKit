//
//  SVImageItem.h
//  Sandvox
//
//  Created by Mike on 15/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <iMedia/IMBComboTextCell.h>

@protocol SVImageItem

- (id)imageRepresentation;
- (NSString *)imageRepresentationType;

@optional
- (NSUInteger) imageVersion;
- (NSString *) imageTitle;
- (NSString *) imageSubtitle;
- (BOOL) isSelectable;

@end
