//
//  NSString+Sundown.h
//  Markdown
//
//  Created by Atsushi Nagase on 5/28/12.
//  Copyright (c) 2012 LittleApps Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "html.h"

@interface NSString (Sundown)

- (NSString *)sd_renderedString;
- (NSString *)sd_renderedStringWithRenderFlags:(unsigned int)render_flags;

@end
