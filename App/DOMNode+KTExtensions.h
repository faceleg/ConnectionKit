//
//  DOMNode+KTExtensions.h
//  KTComponents
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <WebKit/WebKit.h>

@class KTDocument, KTAbstractElement, KTPage;


@interface DOMNode ( KTExtensions )

+ (BOOL)isEditableFromDOMNodeClass:(NSString *)aClass;
+ (BOOL)isImageFromDOMNodeClass:(NSString *)aClass;
+ (BOOL)isSingleLineFromDOMNodeClass:(NSString *)aClass;
+ (BOOL)isLinkableFromDOMNodeClass:(NSString *)aClass;
+ (BOOL)isHTMLElementFromDOMNodeClass:(NSString *)aClass;
+ (BOOL)isSummaryFromDOMNodeClass:(NSString *)aClass;


#pragma mark parent elements

/*! returns nearest parent node of class aClass */
- (id)immediateContainerOfClass:(Class)aClass;

/*! returns whether any parent node if of class aClass */
- (BOOL)isContainedByElementOfClass:(Class)aClass;

#pragma mark index paths
- (DOMNode *)descendantNodeAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathFromNode:(DOMNode *)node;

#pragma mark child elements

/*! recursive method that returns whether node has descendant of aClass */
- (BOOL)hasChildOfClass:(Class)aClass;

/*! recursive method that returns all instances of a particular element */
- (NSArray *)childrenOfClass:(Class)aClass;

/*! returns all child DOMHTMLAnchorElements (a tags) */
- (NSArray *)anchorElements;

/*! returns all child DOMHTMLDivElements (div tags) */
- (NSArray *)divElements;

/*! returns all child DOMHTMLImageElements (img tags) */
- (NSArray *)imageElements;

/*! returns all child DOMHTMLLinkElements (???) */
- (NSArray *)linkElements;

/*! returns all child DOMHTMLObjectElement (object tags) */
- (NSArray *)objectElements;


// Media
- (BOOL)isFileList;
- (void)convertImageSourcesToUseSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)plugin;


- (DOMNode *)removeJunkRecursiveRestrictive:(BOOL)aRestricted allowEmptyParagraphs:(BOOL)anAllowEmptyParagraphs;

#pragma mark Utility

- (void)appendChildren:(DOMNodeList *)aList;

- (void)makePlainTextWithSingleLine:(BOOL)aSingleLine;
- (void)makeSingleLine;

- (DOMHTMLElement *)replaceWithElementName:(NSString *)anElement elementClass:(NSString *)aClass elementID:(NSString *)anID text:(NSString *)aText innerSpan:(BOOL)aSpan innerParagraph:(BOOL)aParagraph;

- (DOMNode *)removeStylesRecursive;
- (void)removeAnyDescendentElementsNamed:(NSString *)elementName;

- (DOMNode *)replaceFakeCDataWithCDATA;	// replace "fakecdata" tag with #TEXT underneath to real CDATA

@end



#pragma mark -


@interface DOMNode ( KTUndo )
+ (DOMNode *)node:(DOMNode *)parent insertBefore:(DOMNode *)newChild :(DOMNode *)refChild;
+ (DOMNode *)node:(DOMNode *)parent appendChild:(DOMNode *)child;
+ (DOMNode *)node:(DOMNode *)parent removeChild:(DOMNode *)child;
@end

#pragma mark -


@interface DOMElement ( KTExtensions )

+ (NSString *)cleanupStyleText:(NSString *)inStyleText restrictUnderlines:(BOOL)aRestrictUnderlines wasItalic:(BOOL *)outWasItalic wasBold:(BOOL *)outWasBold wasTT:(BOOL *)outWasTT;
- (DOMElement *)removeJunkFromParagraphAllowEmpty:(BOOL)anAllowEmptyParagraphs;

- (void)convertImageSourcesToUseSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)plugin;


@end

#pragma mark -


@interface DOMHTMLAnchorElement ( KTUndo )
/*! passing nil for target removes that attribute */
+ (void)element:(DOMHTMLAnchorElement *)anchor setHref:(NSString *)anHref target:(NSString *)aTarget;
@end


@interface DOMHTMLImageElement (KTExtensions)
- (void)convertSourceToUseSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)plugin;
@end
