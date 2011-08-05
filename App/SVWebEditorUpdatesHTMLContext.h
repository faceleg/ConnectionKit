//
//  SVWebEditorUpdatesHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"


@interface SVWebEditorUpdatesHTMLContext : SVWebEditorHTMLContext
{
  @private
    DOMDocument *_document;
}

- (id)initWithDOMDocument:(DOMDocument *)document
             outputWriter:(id <KSWriter>)output
       inheritFromContext:(SVHTMLContext *)context;

@end
