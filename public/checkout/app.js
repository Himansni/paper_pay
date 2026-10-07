// PaperRoute SaaS Web Checkout Client (Option A)

const firebaseConfig = {
  apiKey: "AIzaSyAiqXdkok8p84jUTYKA92eleqpJt4U5i00",
  authDomain: "paperroutedev.firebaseapp.com",
  projectId: "paperroutedev",
  storageBucket: "paperroutedev.appspot.com",
  messagingSenderId: "720004989036",
  appId: "1:720004989036:web:89c7f8865549ef3c4c9849",
};

// Initialize Firebase
if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}

const auth = firebase.auth();
const firestore = firebase.firestore();
const functions = firebase.app().functions("asia-south1");

// Emulators support in local dev if needed
if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
  // If running locally against emulators
  // auth.useEmulator('http://localhost:9099');
  // firestore.useEmulator('localhost', 8080);
  // functions.useEmulator('localhost', 5001);
}

// State
let currentUser = null;
let currentBusinessId = null;
let isAnnual = false;
let subscriptionUnsubscribe = null;

const PRICING = {
  starter: { monthly: 299, annual: 2999 },
  growth: { monthly: 599, annual: 5999 },
  agencyPro: { monthly: 1299, annual: 12999 },
};

// DOM Elements
const authSection = document.getElementById("auth-section");
const checkoutSection = document.getElementById("checkout-section");
const userProfile = document.getElementById("user-profile");
const userEmailSpan = document.getElementById("user-email");
const signoutBtn = document.getElementById("signout-btn");
const loginForm = document.getElementById("login-form");
const authError = document.getElementById("auth-error");

const agencyNameEl = document.getElementById("agency-name");
const agencyIdBadgeEl = document.getElementById("agency-id-badge");
const statusPillEl = document.getElementById("subscription-status-pill");
const expiryInfoEl = document.getElementById("expiry-info");
const billingToggle = document.getElementById("billing-cycle-toggle");
const monthlyLabel = document.getElementById("monthly-label");
const annualLabel = document.getElementById("annual-label");

const paymentModal = document.getElementById("payment-status-modal");
const paymentSpinner = document.getElementById("payment-spinner");
const paymentStatusTitle = document.getElementById("payment-status-title");
const paymentStatusMessage = document.getElementById("payment-status-message");
const closeModalBtn = document.getElementById("close-modal-btn");

// Auth State Listener
auth.onAuthStateChanged(async (user) => {
  currentUser = user;
  if (user) {
    userEmailSpan.textContent = user.email;
    userProfile.classList.remove("hidden");
    authSection.classList.add("hidden");
    checkoutSection.classList.remove("hidden");
    await resolveAndLoadAgency(user);
  } else {
    userProfile.classList.add("hidden");
    authSection.classList.remove("hidden");
    checkoutSection.classList.add("hidden");
    if (subscriptionUnsubscribe) {
      subscriptionUnsubscribe();
      subscriptionUnsubscribe = null;
    }
  }
});

// Login Handler
loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  authError.classList.add("hidden");
  const email = document.getElementById("login-email").value.trim();
  const password = document.getElementById("login-password").value;
  const manualBizId = document.getElementById("login-biz-id").value.trim();

  try {
    const cred = await auth.signInWithEmailAndPassword(email, password);
    if (manualBizId) {
      currentBusinessId = manualBizId;
    }
  } catch (err) {
    authError.textContent = err.message || "Failed to sign in. Please verify your credentials.";
    authError.classList.remove("hidden");
  }
});

// Sign Out Handler
signoutBtn.addEventListener("click", () => {
  auth.signOut();
});

// Resolve Agency for Current User
async function resolveAndLoadAgency(user) {
  try {
    if (!currentBusinessId) {
      // Find business where user is Head
      const ownerSnap = await firestore.doc(`agencyOwners/${user.uid}`).get();
      if (ownerSnap.exists && ownerSnap.data().businessId) {
        currentBusinessId = ownerSnap.data().businessId;
      } else {
        // Fallback search in user profile
        const profileSnap = await firestore.doc(`userProfiles/${user.uid}`).get();
        if (profileSnap.exists && profileSnap.data().businessId) {
          currentBusinessId = profileSnap.data().businessId;
        }
      }
    }

    if (!currentBusinessId) {
      agencyNameEl.textContent = "No Agency Linked";
      agencyIdBadgeEl.textContent = "Please provide Business ID on login";
      return;
    }

    agencyIdBadgeEl.textContent = `Business ID: ${currentBusinessId}`;

    // Load business details
    const bizSnap = await firestore.doc(`businesses/${currentBusinessId}`).get();
    if (bizSnap.exists) {
      agencyNameEl.textContent = bizSnap.data().name || "PaperRoute Agency";
    } else {
      agencyNameEl.textContent = "PaperRoute Agency";
    }

    // Subscribe to live subscription document
    listenToSubscription(currentBusinessId);
  } catch (err) {
    console.error("Error loading agency details:", err);
  }
}

// Live Subscription Listener
function listenToSubscription(bizId) {
  if (subscriptionUnsubscribe) {
    subscriptionUnsubscribe();
  }

  subscriptionUnsubscribe = firestore
    .doc(`businesses/${bizId}/subscription/saas`)
    .onSnapshot((docSnap) => {
      if (!docSnap.exists) {
        statusPillEl.textContent = "No Subscription";
        statusPillEl.className = "status-pill status-expired";
        expiryInfoEl.textContent = "No active trial or paid plan found.";
        return;
      }

      const data = docSnap.data();
      const status = data.status || "trial";
      statusPillEl.textContent = `${data.planId || "Trial"} (${status})`;
      statusPillEl.className = `status-pill status-${status}`;

      if (data.effectiveExpiresAt) {
        const expDate = data.effectiveExpiresAt.toDate ? data.effectiveExpiresAt.toDate() : new Date(data.effectiveExpiresAt);
        expiryInfoEl.textContent = `Active access until: ${expDate.toLocaleDateString("en-IN", {
          year: "numeric",
          month: "short",
          day: "numeric",
        })}`;
      } else {
        expiryInfoEl.textContent = "Expiry date pending evaluation.";
      }
    });
}

// Billing Cycle Toggle
billingToggle.addEventListener("change", (e) => {
  isAnnual = e.target.checked;
  if (isAnnual) {
    annualLabel.classList.add("active");
    monthlyLabel.classList.remove("active");
  } else {
    monthlyLabel.classList.add("active");
    annualLabel.classList.remove("active");
  }
  updatePricingDisplay();
});

function updatePricingDisplay() {
  const period = isAnnual ? "/yr" : "/mo";
  document.getElementById("starter-price").textContent = isAnnual ? "2,999" : "299";
  document.getElementById("starter-period").textContent = period;

  document.getElementById("growth-price").textContent = isAnnual ? "5,999" : "599";
  document.getElementById("growth-period").textContent = period;

  document.getElementById("agencypro-price").textContent = isAnnual ? "12,999" : "1,299";
  document.getElementById("agencypro-period").textContent = period;
}

// Plan Selection & Checkout Initiation
document.querySelectorAll(".select-plan-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const planId = btn.getAttribute("data-plan");
    await initiateCheckout(planId);
  });
});

async function initiateCheckout(planId) {
  if (!currentUser || !currentBusinessId) {
    alert("Please sign in with your Agency Head account first.");
    return;
  }

  showPaymentModal("Preparing Checkout...", "Communicating with PaperRoute billing server...", true);

  try {
    const createCheckoutFn = functions.httpsCallable("createSaasCheckoutSession");
    const result = await createCheckoutFn({
      businessId: currentBusinessId,
      planId,
      billingCycle: isAnnual ? "annual" : "monthly",
    });

    const session = result.data;
    console.log("Checkout session created:", session);

    // If server issued an explicitly isolated simulator session (no live credentials configured)
    if (session.isSimulated) {
      showPaymentModal(
        "Isolated Sandbox Mode Activated",
        `Created server-authenticated simulated checkout session: ${session.subscriptionId}. Razorpay credentials are not configured on this environment. To activate entitlements in dev, invoke the signed webhook simulator with this session ID.`,
        false,
      );
      closeModalBtn.classList.remove("hidden");
      return;
    }

    // Launch Razorpay Recurring Subscriptions Checkout
    const options = {
      key: session.keyId,
      subscription_id: session.subscriptionId,
      name: "PaperRoute SaaS",
      description: `${session.planId.toUpperCase()} Plan (${session.billingCycle})`,
      image: "https://paperroutedev.web.app/favicon.ico",
      notes: session.notes,
      prefill: {
        email: session.customerEmail || currentUser.email,
      },
      theme: {
        color: "#2563eb",
      },
      handler: function (response) {
        showPaymentModal(
          "Subscription Authorized! 🎉",
          `Payment authorization complete (${response.razorpay_payment_id || response.razorpay_subscription_id}). PaperRoute billing servers are activating your agency entitlements.`,
          false,
        );
        closeModalBtn.classList.remove("hidden");
      },
      modal: {
        ondismiss: function () {
          hidePaymentModal();
        },
      },
    };

    if (typeof Razorpay !== "undefined") {
      const rzp = new Razorpay(options);
      rzp.on("payment.failed", function (response) {
        showPaymentModal("Payment Incomplete", response.error.description || "The payment could not be processed.", false);
        closeModalBtn.classList.remove("hidden");
      });
      hidePaymentModal();
      rzp.open();
    } else {
      showPaymentModal(
        "Checkout Ready",
        `Created Razorpay subscription: ${session.subscriptionId}. Razorpay Checkout JS modal will open upon SDK initialization.`,
        false,
      );
      closeModalBtn.classList.remove("hidden");
    }
  } catch (err) {
    console.error("Checkout initiation error:", err);
    showPaymentModal("Checkout Failed", err.message || "Failed to create checkout session.", false);
    closeModalBtn.classList.remove("hidden");
  }
}

function showPaymentModal(title, message, showSpinner) {
  paymentStatusTitle.textContent = title;
  paymentStatusMessage.textContent = message;
  if (showSpinner) {
    paymentSpinner.classList.remove("hidden");
  } else {
    paymentSpinner.classList.add("hidden");
  }
  closeModalBtn.classList.add("hidden");
  paymentModal.classList.remove("hidden");
}

function hidePaymentModal() {
  paymentModal.classList.add("hidden");
}

closeModalBtn.addEventListener("click", () => {
  hidePaymentModal();
});
