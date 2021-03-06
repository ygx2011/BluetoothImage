//
//  AppCache.m
//  AppCache
//
//  Created by developer 03 on 14-3-28.
//  Copyright (c) 2014年 developer 03. All rights reserved.
//

#import "AppCache.h"
#import "ImageBlock.h"
//每个块的上限是500KB
static const unsigned long long BlockSize=500*1024;
static NSString *curPath;
@implementation AppCache

@synthesize Sender;
@synthesize BlockReceivedTable;
@synthesize BlockSendedTable;
@synthesize FileCapacity;
@synthesize ImageReceived;
@synthesize ImageReceiving;
@synthesize ImageSending;
@synthesize ImageSent;


+(AppCache *)shareManager{
    static AppCache *shareAppCacheInstance=nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate,^{
        shareAppCacheInstance=[[AppCache alloc]init];
    });
    return shareAppCacheInstance;
}

-(id)init{
    if (self) {
        assert(self!=nil);
        [self reStoreBaseData];
        //保存本地路径，用于保存分块
        curPath=[[NSFileManager defaultManager]currentDirectoryPath];
    }
    return self;
}

-(ImageBlock *)readDataIsLastBlockFromPath:(NSString *)path ToReceiver:(NSString *)receiver{
    NSFileHandle *inFile=[NSFileHandle fileHandleForReadingAtPath:path];
    assert(inFile!=nil);
    NSString *identify=[self getIdentifyWithSender:self.Sender WithReceiver:receiver AndWithFileName:[path lastPathComponent]];
    [inFile seekToFileOffset:[self getOffSetWithFilePath:identify andDict:self.BlockSendedTable]];
    NSData *data=[inFile readDataOfLength:BlockSize];
    ImageBlock *packet=[[ImageBlock alloc]init];
    //判断文件大小，缓存文件大小，避免每次都重新计算
    //在判断文件大小之后，才可以去判断文件是否到头了
    packet.Total=[self getFileCapacityWithName:path WithIdentify:identify];
    packet.Name=[path lastPathComponent];
    packet.Data=data;
    packet.Sender=self.Sender;
    packet.Receiver=receiver;
    if ([self isEof:inFile andFilename:identify]) {
        packet.Eof=YES;
//        [FileCapacity removeObjectForKey:identify];
        [BlockSendedTable removeObjectForKey:identify];
        [self removeImageSendingWithSender:self.Sender Receiver:receiver andImagePath:path];
        [self addToImageSentWithSender:self.Sender Receiver:receiver ThumbnailPath:@"nil" ImagePath:path];
    }else{
        packet.Eof=NO;
        [self setNextBlockWith:identify andDict:BlockSendedTable];
        [self addToImageSendingWithSender:self.Sender Receiver:receiver ThumbnailPath:@"nil" ImagePath:path Percentage:[self getPercentageWithSendingFile:packet]];
    }
    
    [inFile closeFile];
    return packet;
}

-(void)setNextBlockWith:(NSString *)path andDict:(NSMutableDictionary *)dict{
    //这里有问题，万一【dict objectforkey：path】为空
    int newValue=[[dict objectForKey:path]intValue]+1;
    [dict setObject:[NSNumber numberWithInt:newValue] forKey:path];
}

-(BOOL)isEof:(NSFileHandle *)handle andFilename:(NSString *)name{
    unsigned long long cur=[handle offsetInFile];
    unsigned long long end=[[FileCapacity objectForKey:name]unsignedLongLongValue];
    if(cur>=end){
        return YES;
    }
    return NO;
}

-(unsigned long long)getFileCapacityWithName:(NSString *)name WithIdentify:(NSString *) identify{
    if([FileCapacity objectForKey:identify]==nil){
        unsigned long long length=[[[NSFileManager defaultManager]contentsAtPath:name]length];
        [FileCapacity setObject:[NSNumber numberWithUnsignedLongLong:length] forKey:identify];
    }
    return [[FileCapacity objectForKey:identify]unsignedLongLongValue];
}

-(NSUInteger)getOffSetWithFilePath:(NSString *)path andDict:(NSMutableDictionary *) dict{
    if ([dict objectForKey:path]==nil) {
        [dict setObject:[NSNumber numberWithInteger:0] forKey:path];
        return 0*BlockSize;
    } else {
        return [[dict objectForKey:path]intValue]*BlockSize;
    }
}

-(NSString *)storeData:(ImageBlock *)image{
//    image.Name=@"/Users/developer03/Desktop/text/testImg.jpg";
    if ([self isFileExistentWithFileName:image.Name]==NO){
        [[NSFileManager defaultManager] createFileAtPath:image.Name contents:nil attributes:nil];
    }
    NSString *path=[NSString stringWithFormat:@"%@/%@",curPath,image.Name];
    NSFileHandle *outFile=[NSFileHandle fileHandleForWritingAtPath:image.Name];
    unsigned long long length=[self getOffSetWithFilePath:image.Name andDict:BlockReceivedTable];
    [outFile seekToFileOffset:length];
    [outFile writeData:image.Data];
    [outFile closeFile];
    if (image.Eof) {
        [BlockReceivedTable removeObjectForKey:image.Name];
//        [ImageReceived addObject:image.Name];
        //这里也要找到该文件的path
        [self removeImageReceivingWithSender:image.Sender Receiver:self.Sender andImagePath:path];
        [self addToImageReceivedWithSender:image.Sender Receiver:self.Sender ThumbnailPath:@"nil" ImagePath:path];
        return @"100%";
    }else{
        [self setNextBlockWith:image.Name andDict:BlockReceivedTable];
        NSString *percentage=[NSString stringWithFormat:@"%.1llu%%",(length+BlockSize)*100/image.Total];
        //这里要找到文件的path
        [self addToImageReceivingWithSender:image.Sender Receiver:self.Sender ThumbnailPath:@"nil" ImagePath:path Percentage:percentage];
        return percentage;
    }
    
}

-(BOOL)isFileExistentWithFileName:(NSString *)fileName{
    if([BlockReceivedTable objectForKey:fileName]==nil)
        return NO;
    return YES;
}

//序列化
-(void)storeBaseData{
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = path[0];
    //局部变量，只有在用的时候才创建
    NSString *BlockReceivedTablePath=[documentDir stringByAppendingString:@"/BlockReceivedTablePath1.plist"];
    NSString *BlockSendedTablePath=[documentDir stringByAppendingString:@"/BlockSendedTable1.plist"];
    NSString *FileCapacityPath=[documentDir stringByAppendingString:@"/FileCapacity1.plist"];
    NSString *SenderPath=[documentDir stringByAppendingString:@"/Sender1.plist"];
    NSString *ImageReceivedPath=[documentDir stringByAppendingString:@"/ImageReceived1.plist"];
    NSString *ImageReceivingPath=[documentDir stringByAppendingString:@"/ImageReceiving1.plist"];
    NSString *ImageSentPath=[documentDir stringByAppendingString:@"/ImageSent1.plist"];
    NSString *ImageSendingPath=[documentDir stringByAppendingString:@"/ImageSending1.plist"];

    [self.BlockReceivedTable writeToFile:BlockReceivedTablePath atomically:YES];
    [self.BlockSendedTable writeToFile:BlockSendedTablePath atomically:YES];
    [self.FileCapacity writeToFile:FileCapacityPath atomically:YES];
    [self.Sender writeToFile:SenderPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self.ImageReceived writeToFile:ImageReceivedPath atomically:YES];
    [self.ImageReceiving writeToFile:ImageReceivingPath atomically:YES];
    [self.ImageSent writeToFile:ImageSentPath atomically:YES];
    [self.ImageSending writeToFile:ImageSendingPath atomically:YES];
}

//反序列化
-(void)reStoreBaseData{
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = path[0];
    //局部变量，只有在用的时候才创建
    NSString *BlockReceivedTablePath=[documentDir stringByAppendingString:@"/BlockReceivedTablePath1.plist"];
    NSString *BlockSendedTablePath=[documentDir stringByAppendingString:@"/BlockSendedTable1.plist"];
    NSString *FileCapacityPath=[documentDir stringByAppendingString:@"/FileCapacity1.plist"];
    NSString *SenderPath=[documentDir stringByAppendingString:@"/Sender1.plist"];
    NSString *ImageReceivedPath=[documentDir stringByAppendingString:@"/ImageReceived1.plist"];
    NSString *ImageReceivingPath=[documentDir stringByAppendingString:@"/ImageReceiving1.plist"];
    NSString *ImageSentPath=[documentDir stringByAppendingString:@"/ImageSent1.plist"];
    NSString *ImageSendingPath=[documentDir stringByAppendingString:@"/ImageSending1.plist"];
    
    //第一次打开应用程序时，下面4项是nil
    self.BlockReceivedTable=[self reStoreDictWithPath:BlockReceivedTablePath];
    self.BlockSendedTable=[self reStoreDictWithPath:BlockSendedTablePath];
    self.FileCapacity=[self reStoreDictWithPath:FileCapacityPath];
    self.Sender=[self reStroeSenderWithPath:SenderPath];
    self.ImageReceived=[self reStoreDictWithPath:ImageReceivedPath];
    self.ImageReceiving=[self reStoreDictWithPath:ImageReceivingPath];
    self.ImageSent=[self reStoreDictWithPath:ImageSentPath];
    self.ImageSending=[self reStoreDictWithPath:ImageSendingPath];
}

-(NSMutableDictionary *)reStoreDictWithPath:(NSString *)path{
    NSMutableDictionary *temp=[[NSMutableDictionary alloc]initWithContentsOfFile:path];
    if(temp==nil)
        temp=[[NSMutableDictionary alloc]initWithCapacity:20];
    return temp;
}

-(NSString *)reStroeSenderWithPath:(NSString *)path{
    NSString *temp=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if(temp==nil)
        temp=@"chuyang";
    return temp;
}

-(NSMutableArray *)reStoreArrayWithPath:(NSString *)path{
    NSMutableArray *temp=[NSMutableArray arrayWithContentsOfFile:path];
    if(temp==nil)
        temp=[[NSMutableArray alloc]initWithCapacity:20];
    return temp;
}

-(NSString *)getPercentageWithSendingFile:(ImageBlock *)file{
    NSString *identify=[self getIdentifyWithSender:file.Sender WithReceiver:file.Receiver AndWithFileName:file.Name];
    unsigned long long capacity=[[FileCapacity objectForKey:identify]unsignedLongLongValue];
    unsigned long long hadLoad=[[BlockSendedTable objectForKey:identify]intValue]*BlockSize;
    NSString *percentage=[NSString stringWithFormat:@"%.1llu%%",hadLoad*100/capacity];
    return percentage;
}

-(NSString *)getIdentifyWithSender:(NSString *)sender WithReceiver:(NSString *)receiver AndWithFileName:(NSString *)name{
    return [NSString stringWithFormat:@"/%@/%@/%@",sender,receiver,name];
}

-(NSArray *)getImageReceived{
    return [ImageReceived allValues];
}

-(NSArray *)getImageReceiving{
    return [ImageReceiving allValues];
}

-(NSArray *)getImageSent{
    return [ImageSent allValues];
}

-(NSArray *)getImageSending{
    return [ImageSending allValues];
}

-(void)addToImageSendingWithSender:(NSString *)sender Receiver:(NSString *) receiver ThumbnailPath:(NSString *)thumbnailPath ImagePath:(NSString *)imagePath Percentage:(NSString *)percentage{
    NSString *identify=[self getIdentifyWithSender:Sender WithReceiver:receiver AndWithFileName:[imagePath lastPathComponent]];
    if([ImageSending objectForKey:identify]==nil){
        NSMutableArray *temp=[[NSMutableArray alloc]init];
        [temp addObject:receiver];
        [temp addObject:thumbnailPath];
        [temp addObject:imagePath];
        [temp addObject:percentage];
        [ImageSending setObject:temp forKey:identify];
    }else{
        NSMutableArray *temp=[ImageSending objectForKey:identify];
        [temp setObject:percentage atIndexedSubscript:3];
    }
    
}

-(void)removeImageSendingWithSender:(NSString *)sender Receiver:(NSString *)receiver andImagePath:(NSString *)imagePath{
    NSString *identify=[self getIdentifyWithSender:Sender WithReceiver:receiver AndWithFileName:[imagePath lastPathComponent]];
    [ImageSending removeObjectForKey:identify];
}

-(void)addToImageSentWithSender:(NSString *)sender Receiver:(NSString *) receiver ThumbnailPath:(NSString *)thumbnailPath ImagePath:(NSString *)imagePath{
    NSString *identify=[self getIdentifyWithSender:Sender WithReceiver:receiver AndWithFileName:[imagePath lastPathComponent]];
    NSMutableArray *temp=[[NSMutableArray alloc]init];
    [temp addObject:receiver];
    [temp addObject:thumbnailPath];
    [temp addObject:imagePath];
    [ImageSent setObject:temp forKey:identify];
}

-(void)addToImageReceivingWithSender:(NSString *)sender Receiver:(NSString *) receiver ThumbnailPath:(NSString *)thumbnailPath ImagePath:(NSString *)imagePath Percentage:(NSString *)percentage{
    NSString *identify=[self getIdentifyWithSender:Sender WithReceiver:receiver AndWithFileName:[imagePath lastPathComponent]];
    if([ImageReceiving objectForKey:identify]==nil){
        NSMutableArray *temp=[[NSMutableArray alloc]init];
        [temp addObject:sender];
        [temp addObject:thumbnailPath];
        [temp addObject:imagePath];
        [temp addObject:percentage];
        [ImageReceiving setObject:temp forKey:identify];
    }else{
        NSMutableArray *temp=[ImageSending objectForKey:identify];
        [temp setObject:percentage atIndexedSubscript:3];
    }
        
}

-(void)removeImageReceivingWithSender:(NSString *)sender Receiver:(NSString *)receiver andImagePath:(NSString *)imagePath{
    NSString *identify=[self getIdentifyWithSender:Sender WithReceiver:receiver AndWithFileName:[imagePath lastPathComponent]];
    [ImageReceiving removeObjectForKey:identify];
}

-(void)addToImageReceivedWithSender:(NSString *)sender Receiver:(NSString *) receiver ThumbnailPath:(NSString *)thumbnailPath ImagePath:(NSString *)imagePath{
    NSString *identify=[self getIdentifyWithSender:Sender WithReceiver:receiver AndWithFileName:[imagePath lastPathComponent]];
    NSMutableArray *temp=[[NSMutableArray alloc]init];
    [temp addObject:receiver];
    [temp addObject:thumbnailPath];
    [temp addObject:imagePath];
    [ImageReceived setObject:temp forKey:identify];
}
@end
