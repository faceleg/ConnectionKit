//
//  KTAbstractPage+Internal.h
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTAbstractPage.h"
#import "KTWebViewComponent.h"


@interface KTAbstractPage (Internal) <KTWebViewComponent>

+ (NSCharacterSet *)uniqueIDCharacters;

@end
