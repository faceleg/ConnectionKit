//
//  NSOutlineView+KTExtensions.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
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

#import <AppKit/NSOutlineView.h>


@interface NSOutlineView ( KTExtensions ) 

- (void)expandSelectedRow;

- (void)selectItem:(id)anItem;
- (void)selectItem:(id)anItem forceDidChangeNotification:(BOOL)aFlag;

- (void)selectItems:(NSArray *)theItems;
- (void)selectItems:(NSArray *)theItems forceDidChangeNotification:(BOOL)aFlag;

- (id)selectedItem;
- (NSArray *)selectedItems;

- (id)itemAboveFirstSelectedRow;

- (NSSet *)itemsForRows:(NSIndexSet *)rowsIndexes;

/*! returns outline cell via private name */
- (id)_outlineCell;

@end
