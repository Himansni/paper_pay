const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  role: { type: String, enum: ['agency', 'customer'], required: true },
  email: { type: String, unique: true, sparse: true },
  phone: { type: String, unique: true, sparse: true },
  passwordHash: { type: String, required: true },

  // Common profile fields
  name: String,
  location: String,
  mobileNumber: String, // optional for customer
  profilePhotoUrl: String,
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);