const mongoose = require('mongoose');

const groupHeadSchema = new mongoose.Schema({
  name: String,
  mobileNumber: String,
  customers: [{
    name: String,
    houseNumber: String,
    location: String,
    phone: String,
    priceHistory: [{ date: Date, price: Number }],  // track daily price
    monthlyPaymentDone: Boolean,
    paymentDueDate: Date,
    paperClosed: Boolean,
  }]
});

const agencyProfileSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  feedback: String,
  supportContact: String,
  dailyNewspaperPrice: Number,
  groupHeads: [groupHeadSchema],
  messagesFromCustomer: [{
    fromCustomerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    message: String,
    date: Date,
  }]
});

module.exports = mongoose.model('AgencyProfile', agencyProfileSchema);