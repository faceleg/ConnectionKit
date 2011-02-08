//
//  SVPageThumbnailController.h
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVFillController.h"
#import "SVPageThumbnailHTMLContext.h"
#import "KSDependenciesTracker.h"

#import <BWToolkitFramework/BWToolkitFramework.h>



@interface SVPageThumbnailController : SVFillController <SVPageThumbnailHTMLContextDelegate, KSDependenciesTrackerDelegate>
{
    IBOutlet NSPopUpButton  *oImagePicker;
  @private
    KSDependenciesTracker   *_dependenciesTracker;
}

@property(nonatomic, readonly) BOOL fillTypeIsImage;
@property(nonatomic, readonly) BOOL fillTypeIsCustomImage;

@end


#pragma mark -


@interface SVFillTypeFromThumbnailType : NSValueTransformer
@end


#pragma mark -


@interface SVPageThumbnailPickerCell : BWIWorkPopUpButtonCell

@end

