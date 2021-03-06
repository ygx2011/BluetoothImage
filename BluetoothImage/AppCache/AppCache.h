//
//  AppCache.h
//  AppCache
//
//  Created by developer 03 on 14-3-28.
//  Copyright (c) 2014年 developer 03. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImageBlock.h"
@interface AppCache : NSObject
{
    NSMutableDictionary *BlockReceivedTable;//记录正在接受的块的块号，接受完毕后删除对应项
    NSMutableDictionary *BlockSendedTable;//记录正在发送的块的块号，发送完毕后删除对应项
    NSMutableDictionary *FileCapacity;//每个文件的大小
    NSMutableDictionary *ImageReceived;//已经接收完毕的图片的信息
    NSMutableDictionary *ImageReceiving;//还没有接收完毕的图片的信息
    NSMutableDictionary *ImageSent;//已经发送完毕的完毕的图片的信息
    NSMutableDictionary *ImageSending;//还没有发送完毕的图片的信息
    NSString *Sender;//发送者的名字，可以是发送机器的uuid,有一个默认值
}

@property(nonatomic)NSString *Sender;
//记录某张图片接受到第几个分块，如果最后一块也接受完了，把对应的key/value删除
@property(nonatomic) NSMutableDictionary *BlockReceivedTable;
//记录某张图片发送到第几个分块，如果最后一块也发送完毕，把对应的key/value删除
@property(nonatomic) NSMutableDictionary *BlockSendedTable;
//记录正在发送的文件的大小，发送完毕后把对应key/value删除
@property(nonatomic) NSMutableDictionary *FileCapacity;

@property(nonatomic) NSMutableDictionary *ImageReceived;
@property(nonatomic) NSMutableDictionary *ImageReceiving;
@property(nonatomic) NSMutableDictionary *ImageSent;
@property(nonatomic) NSMutableDictionary *ImageSending;

//获取AppCache单例
+(AppCache *)shareManager;

//imageBlock是一个分块，接受完一个分块后调用该方法，其返回值是接受该文件的百分比
-(NSString *)storeData:(ImageBlock *)imageBlock;

//该方法会分块读取图片，读取完一个分块应该把该分块发送出去，删除该分块，再调用该方法，直到读完为止
//path是图片在闪存的路径，返回的NSMutableDictionary包含isLastBlock（最后一个分块）、data（Image对象）
-(ImageBlock *)readDataIsLastBlockFromPath:(NSString *)path ToReceiver:(NSString *)receiver;

//在应用程序结束的时候调用，把BlockReceivedTable、BlockSendedTable、FileCapacity和Sender储存到硬盘，下次打开应用的时候再把他们加载进内存
-(void)storeBaseData;

//在应用程序打开的时候调用，把上次保存的BlockReceivedTable、BlockSendedTable、FileCapacity和Sender恢复到内存
-(void)reStoreBaseData;

//获取发送某个文件的百分比
-(NSString *)getPercentageWithSendingFile:(ImageBlock *)flie;

//返回已经接收完毕的图片的信息
//返回的数组每一项是NSArray,分别是SenderhumbnailPath（缩略图路径）和imagePath（真正的路径）
-(NSArray *)getImageReceived;

//返回已经发送完毕的图片的信息
//返回的数组每一项是NSArray,分别是Receiver、thumbnailPath（缩略图路径）和imagePath（真正的路径）
-(NSArray *)getImageSent;

//返回还没有接收完毕的图片的信息
//返回的数组每一项是NSArray,分别是Sender、thumbnailPath（缩略图路径）、imagePath（真正的路径）和百分比
-(NSArray *)getImageReceiving;

//返回还没有发送完毕的图片的信息
//返回的数组每一项是NSArray,分别是Receiver、thumbnailPath（缩略图路径）、imagePath（真正的路径）和百分比
-(NSArray *)getImageSending;
@end
