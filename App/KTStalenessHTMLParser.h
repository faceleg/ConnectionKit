//
//  KTStalenessHTMLParser.h
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

//	A subclass of KTHTML parser that is optimised to run as fast as possible
//	for building staleness information. i.e. The delegate methods work correctly,
//	but the returned HTML is not guaranteed to be suitable for display/publishing.

#import <Cocoa/Cocoa.h>
#import "SVHTMLTemplateParser.h"


@interface KTStalenessHTMLParser : SVHTMLTemplateParser
{
}

@end
