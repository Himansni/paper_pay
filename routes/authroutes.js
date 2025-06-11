const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const AgencyProfile = require('../models/AgencyProfile');

const JWT_SECRET = process.env.JWT_SECRET || "secretkeyforjwt";

// Register route
router.post('/signup', async (req, res) => {
  const { role, email, phone, password, name, location, mobileNumber } = req.body;

  if (!role || !password) return res.status(400).json({ msg: "Role and password required" });
  
  try {
    let existingUser = null;
    if(email) existingUser = await User.findOne({ email });
    else if(phone) existingUser = await User.findOne({ phone });
    if (existingUser) return res.status(400).json({ msg: "User already exists" });

    const passwordHash = await bcrypt.hash(password, 10);

    const user = new User({
      role,
      email,
      phone,
      passwordHash,
      name,
      location,
      mobileNumber
    });

    await user.save();

    // If agency, create agency profile too
    if(role === 'agency') {
      const aProfile = new AgencyProfile({ userId: user._id });
      await aProfile.save();
    }

    const token = jwt.sign({ userId: user._id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, user: { id: user._id, role: user.role, name: user.name } });
  } catch(err) {
    res.status(500).json({ error: err.message });
  }
});

// Login route
router.post('/login', async (req, res) => {
  const { email, phone, password } = req.body;
  if (!password || (!email && !phone)) return res.status(400).json({ msg: "Email/Phone and password required" });

  try {
    let user = null;
    if(email) user = await User.findOne({ email });
    else if(phone) user = await User.findOne({ phone });

    if (!user) return res.status(400).json({ msg: "User not found" });

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) return res.status(400).json({ msg: "Invalid credentials" });

    const token = jwt.sign({ userId: user._id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });

    res.json({ token, user: { id: user._id, role: user.role, name: user.name } });
  } catch(err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;