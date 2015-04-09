//
//  CDTEncryptionKeychainUtils+AES.m
//
//
//  Created by Enrique de la Torre Fernandez on 09/04/2015.
//
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTEncryptionKeychainUtils+AES.h"
#import "CDTEncryptionKeychainUtils+Base64.h"

#import <openssl/evp.h>
#import <openssl/aes.h>

#import "CDTEncryptionKeychainConstants.h"
#import "NSString+CharBufferFromHexString.h"

@implementation CDTEncryptionKeychainUtils (AES)

#pragma mark - Public class methods
+ (NSData *)doDecrypt:(NSString *)ciphertextEncoded key:(NSString *)key withIV:(NSString *)iv
{
    NSData *cipherText = [CDTEncryptionKeychainUtils base64DataFromString:ciphertextEncoded];

    unsigned char *nativeKey = [key charBufferFromHexStringWithSize:CDTkChosenCipherKeySize];
    unsigned char *nativeIv = [iv charBufferFromHexStringWithSize:CDTkChosenCipherIVSize];

    EVP_CIPHER_CTX ctx;
    EVP_CIPHER_CTX_init(&ctx);
    EVP_DecryptInit_ex(&ctx, EVP_aes_256_cbc(), NULL, nativeKey, nativeIv);

    unsigned char *cipherTextBytes = (unsigned char *)[cipherText bytes];
    int cipherTextBytesLength = (int)[cipherText length];

    unsigned char *decryptedBytes = aes_decrypt(&ctx, cipherTextBytes, &cipherTextBytesLength);
    NSData *decryptedData = [NSData dataWithBytes:decryptedBytes length:cipherTextBytesLength];

    EVP_CIPHER_CTX_cleanup(&ctx);

    bzero(decryptedBytes, cipherTextBytesLength);
    free(decryptedBytes);

    bzero(nativeKey, CDTkChosenCipherKeySize);
    free(nativeKey);

    bzero(nativeIv, CDTkChosenCipherIVSize);
    free(nativeIv);

    return decryptedData;
}

+ (NSData *)doEncrypt:(NSString *)text key:(NSString *)key withIV:(NSString *)iv
{
    NSData *myText = [text dataUsingEncoding:NSUnicodeStringEncoding];

    unsigned char *nativeIv = [iv charBufferFromHexStringWithSize:CDTkChosenCipherIVSize];
    unsigned char *nativeKey = [key charBufferFromHexStringWithSize:CDTkChosenCipherKeySize];

    EVP_CIPHER_CTX ctx;
    EVP_CIPHER_CTX_init(&ctx);
    EVP_EncryptInit_ex(&ctx, EVP_aes_256_cbc(), NULL, nativeKey, nativeIv);

    unsigned char *textBytes = (unsigned char *)[myText bytes];
    int textBytesLength = (int)[myText length];

    unsigned char *encryptedBytes = aes_encrypt(&ctx, textBytes, &textBytesLength);
    NSData *encryptedData = [NSData dataWithBytes:encryptedBytes length:textBytesLength];

    EVP_CIPHER_CTX_cleanup(&ctx);

    bzero(encryptedBytes, textBytesLength);
    free(encryptedBytes);

    bzero(nativeKey, CDTkChosenCipherKeySize);
    free(nativeKey);

    bzero(nativeIv, CDTkChosenCipherIVSize);
    free(nativeIv);

    return encryptedData;
}

#pragma mark - Private class methods
/*
 * Caller MUST FREE memory returned from this method
 * Decryption using OpenSSL decryption aes256
 * Decrypt *len bytes of ciphertext
 */
static unsigned char *aes_decrypt(EVP_CIPHER_CTX *e, unsigned char *ciphertext, int *len)
{
    /* plaintext will always be equal to or lesser than length of ciphertext*/
    int p_len = *len, f_len = 0;
    unsigned char *plaintext = malloc(p_len + AES_BLOCK_SIZE);

    EVP_DecryptInit_ex(e, NULL, NULL, NULL, NULL);
    EVP_DecryptUpdate(e, plaintext, &p_len, ciphertext, *len);
    EVP_DecryptFinal_ex(e, plaintext + p_len, &f_len);

    *len = p_len + f_len;
    return plaintext;
}

/*
 * Caller MUST FREE memory returned from this method
 * Encryption using OpenSSL encryption aes256
 * Encrypt *len bytes of data
 * All data going in & out is considered binary (unsigned char[])
 */
static unsigned char *aes_encrypt(EVP_CIPHER_CTX *e, unsigned char *plaintext, int *len)
{
    /* max ciphertext len for a n bytes of plaintext is n + AES_BLOCK_SIZE -1 bytes */
    int c_len = *len + AES_BLOCK_SIZE, f_len = 0;
    unsigned char *ciphertext = malloc(c_len);

    /* allows reusing of 'e' for multiple encryption cycles */
    EVP_EncryptInit_ex(e, NULL, NULL, NULL, NULL);

    /* update ciphertext, c_len is filled with the length of ciphertext generated,
     *len is the size of plaintext in bytes */
    EVP_EncryptUpdate(e, ciphertext, &c_len, plaintext, *len);

    /* update ciphertext with the final remaining bytes */
    EVP_EncryptFinal_ex(e, ciphertext + c_len, &f_len);

    *len = c_len + f_len;
    return ciphertext;
}

@end
