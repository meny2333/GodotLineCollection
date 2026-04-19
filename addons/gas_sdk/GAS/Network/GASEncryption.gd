class_name GASEncryption
extends RefCounted


static func derive_key_bytes(raw_key: String) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw_key.to_utf8_buffer())
	return ctx.finish()


static func encrypt(plain_text: String, raw_key: String) -> String:
	if plain_text == "" or raw_key == "":
		return ""
	var key_bytes: PackedByteArray = derive_key_bytes(raw_key)
	var iv: PackedByteArray = PackedByteArray()
	iv.resize(16)
	return _aes_encrypt(plain_text.to_utf8_buffer(), key_bytes, iv)


static func decrypt(cipher_text: String, raw_key: String) -> String:
	if cipher_text == "" or raw_key == "":
		return ""
	var key_bytes: PackedByteArray = derive_key_bytes(raw_key)
	var iv: PackedByteArray = PackedByteArray()
	iv.resize(16)
	return _aes_decrypt(cipher_text, key_bytes, iv)


static func _aes_encrypt(plain_bytes: PackedByteArray, key: PackedByteArray, iv: PackedByteArray) -> String:
	var encrypted: PackedByteArray = _aes_encrypt_bytes(plain_bytes, key, iv)
	return Marshalls.raw_to_base64(encrypted)


static func _aes_encrypt_bytes(plain_bytes: PackedByteArray, key: PackedByteArray, iv: PackedByteArray) -> PackedByteArray:
	var aes: AESContext = AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var pad_len: int = 16 - (plain_bytes.size() % 16)
	var padded: PackedByteArray = plain_bytes.duplicate()
	padded.resize(plain_bytes.size() + pad_len)
	for i in range(pad_len):
		padded[plain_bytes.size() + i] = pad_len
	var encrypted: PackedByteArray = aes.update(padded)
	aes.finish()
	return encrypted


static func _aes_decrypt(encrypted_b64: String, key: PackedByteArray, iv: PackedByteArray) -> String:
	var encrypted: PackedByteArray = Marshalls.base64_to_raw(encrypted_b64)
	var decrypted: PackedByteArray = _aes_decrypt_bytes(encrypted, key, iv)
	return decrypted.get_string_from_utf8()


static func _aes_decrypt_bytes(encrypted: PackedByteArray, key: PackedByteArray, iv: PackedByteArray) -> PackedByteArray:
	if encrypted.size() == 0:
		return PackedByteArray()
	var aes: AESContext = AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var decrypted: PackedByteArray = aes.update(encrypted)
	aes.finish()
	if decrypted.size() > 0:
		var pad_len: int = decrypted[decrypted.size() - 1]
		if pad_len > 0 and pad_len <= 16 and decrypted.size() >= pad_len:
			var valid_padding: bool = true
			for i in range(pad_len):
				if decrypted[decrypted.size() - 1 - i] != pad_len:
					valid_padding = false
					break
			if valid_padding:
				decrypted.resize(decrypted.size() - pad_len)
	return decrypted