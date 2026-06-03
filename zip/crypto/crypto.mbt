///|
pub struct ZipCrypto {
  mut key0 : UInt
  mut key1 : UInt
  mut key2 : UInt
}

///|
pub fn ZipCrypto::new() -> ZipCrypto {
  { key0: 0x12345678U, key1: 0x23456789U, key2: 0x34567890U }
}

///|
fn ZipCrypto::update(self : ZipCrypto, byte : Byte) -> Unit {
  self.key0 = @checksum.crc32_update_byte(self.key0, byte)
  self.key1 = (self.key1 + (self.key0 & 0xFFU)) * 134775813U + 1U
  self.key2 = @checksum.crc32_update_byte(
    self.key2,
    (self.key1 >> 24).to_byte(),
  )
}

///|
fn ZipCrypto::decrypt_byte(self : ZipCrypto) -> Byte {
  let temp = (self.key2 | 2U) & 0xFFFFU
  ((temp * (temp ^ 1U)) >> 8).to_byte()
}

///|
fn ZipCrypto::init_with_password(self : ZipCrypto, password : Bytes) -> Unit {
  for i = 0; i < password.length(); i = i + 1 {
    self.update(password[i])
  }
}

///|
pub fn zip_crypto_encrypt(password : Bytes, data : Bytes) -> Bytes {
  let crypto = ZipCrypto::new()
  crypto.init_with_password(password)

  let result = Buffer::Buffer()
  for i in 0..<data.length() {
    let t = crypto.decrypt_byte()
    let encrypted = data[i] ^ t
    result.write_byte(encrypted)
    crypto.update(encrypted)
  }
  result.to_bytes()
}

///|
pub fn zip_crypto_decrypt(password : Bytes, data : Bytes) -> Bytes {
  let crypto = ZipCrypto::new()
  crypto.init_with_password(password)

  let result = Buffer::Buffer()
  for i in 0..<data.length() {
    let t = crypto.decrypt_byte()
    let encrypted = data[i]
    let decrypted = encrypted ^ t
    result.write_byte(decrypted)
    crypto.update(encrypted)
  }
  result.to_bytes()
}

///|
pub fn make_encryption_header(password : Bytes, crc : UInt) -> Bytes {
  let crypto = ZipCrypto::new()
  crypto.init_with_password(password)

  let result = Buffer::Buffer()
  for _ in 0..<11 {
    let random_byte = (0).to_byte()
    let t = crypto.decrypt_byte()
    let encrypted = random_byte ^ t
    result.write_byte(encrypted)
    crypto.update(random_byte)
  }

  let check_byte = (crc >> 24).to_byte()
  let t = crypto.decrypt_byte()
  let encrypted = check_byte ^ t
  result.write_byte(encrypted)
  crypto.update(check_byte)

  result.to_bytes()
}

///|
pub fn verify_encryption_header(
  data : Bytes,
  password : Bytes,
  crc : UInt,
) -> Bool {
  if data.length() < 12 {
    return false
  }

  let crypto = ZipCrypto::new()
  crypto.init_with_password(password)

  let decrypted = Buffer::Buffer()
  for i in 0..<12 {
    let t = crypto.decrypt_byte()
    let d = data[i] ^ t
    crypto.update(d)
    decrypted.write_byte(d)
  }

  let decrypted_bytes = decrypted.to_bytes()
  let expected_check = (crc >> 24).to_byte()
  decrypted_bytes[11] == expected_check
}
