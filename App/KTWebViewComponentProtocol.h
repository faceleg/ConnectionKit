//
//  KTWebViewComponent.h
//  Marvel
//
//  Created by Mike on 23/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//


@protocol KTWebViewComponent <NSObject>

//	Return as unique an ID to identify the object as possible.
//	e.g. @"ktpagelet-100"
- (NSString *)uniqueWebViewID;

@end
