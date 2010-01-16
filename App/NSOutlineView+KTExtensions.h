//
//  NSOutlineView+KTExtensions.h
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

#import <AppKit/NSOutlineView.h>


@interface NSOutlineView (KTExtensions)

#pragma mark Items
- (int)numberOfChildrenOfItem:(id)item;
- (id)child:(int)index ofItem:(id)item;

- (NSArray *)itemsAtRows:(NSIndexSet *)rowsIndexes;
- (NSIndexSet *)rowsForItems:(NSArray *)items;

#pragma mark Selection
- (void)expandSelectedRow;
- (int)makeItemVisible:(id)item;

- (void)selectItem:(id)anItem;
- (void)selectItem:(id)anItem forceDidChangeNotification:(BOOL)aFlag;

- (void)selectItems:(NSArray *)theItems;
- (void)selectItems:(NSArray *)theItems forceDidChangeNotification:(BOOL)aFlag;

- (id)selectedItem;
- (NSArray *)selectedItems;

- (id)itemAboveFirstSelectedRow;

#pragma mark Drawing
- (void)setItemNeedsDisplay:(id)item childrenNeedDisplay:(BOOL)recursive;
- (id)lastVisibleChildOfItem:(id)item;

@end


@interface NSObject (KTOutlineViewDataSourceExtensions)
- (id)outlineView:(NSOutlineView *)outlineView parentOfItem:(id)item;
@end
