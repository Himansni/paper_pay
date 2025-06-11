const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const AgencyProfile = require('../models/AgencyProfile');
const User = require('../models/User');

// Middleware to check agency role
function agencyOnly(req, res, next) {
  if (req.user.role !== 'agency') return res.status(403).json({ msg: "Access denied" });
  next();
}

// Get agency profile
router.get('/profile', authMiddleware, agencyOnly, async (req, res) => {
  try {
    const profile = await AgencyProfile.findOne({userId: req.user.userId});
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update daily price
router.post('/setDailyPrice', authMiddleware, agencyOnly, async (req, res) => {
  const { dailyPrice } = req.body;
  if (!dailyPrice) return res.status(400).json({ msg: "Daily price required" });

  try {
    const profile = await AgencyProfile.findOne({ userId: req.user.userId });
    profile.dailyNewspaperPrice = dailyPrice;
    await profile.save();
    res.json({ msg: "Daily price updated" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add Group Head
router.post('/groupHead', authMiddleware, agencyOnly, async (req, res) => {
  const { name, mobileNumber } = req.body;
  if (!name || !mobileNumber) return res.status(400).json({ msg: "Name and mobileNumber required" });
  try {
    const profile = await AgencyProfile.findOne({ userId: req.user.userId });
    profile.groupHeads.push({ name, mobileNumber, customers: [] });
    await profile.save();
    res.json({ msg: "Group head added", groupHeads: profile.groupHeads });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add customer to group head
router.post('/groupHead/:groupHeadId/customer', authMiddleware, agencyOnly, async (req, res) => {
  const groupHeadId = req.params.groupHeadId;
  const { name, houseNumber, location, phone } = req.body;
  if (!name || !phone) return res.status(400).json({ msg: "Name and phone required" });

  try {
    const profile = await AgencyProfile.findOne({ userId: req.user.userId });
    const groupHead = profile.groupHeads.id(groupHeadId);
    if (!groupHead) return res.status(404).json({ msg: "Group head not found" });

    groupHead.customers.push({
      name,
      houseNumber,
      location,
      phone,
      priceHistory: [],
      monthlyPaymentDone: false,
      paymentDueDate: null,
      paperClosed: false,
    });
    await profile.save();
    res.json({ msg: "Customer added", customers: groupHead.customers });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Other routes like update agency info, edit/delete group head or customer etc can follow similarly.

module.exports = router;