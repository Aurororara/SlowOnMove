import hashlib
import urllib.parse
from datetime import datetime

class ECPayService:
    SANDBOX_CHECKOUT_URL = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5"
    SANDBOX_MERCHANT_ID = "3002607"
    SANDBOX_HASH_KEY = "pwFQuSpCvhLGlMcw"
    SANDBOX_HASH_IV = "v77hoKGq4kWxNNIS"

    @classmethod
    def generate_check_mac_value(cls, params, hash_key=None, hash_iv=None):
        if hash_key is None:
            hash_key = cls.SANDBOX_HASH_KEY
        if hash_iv is None:
            hash_iv = cls.SANDBOX_HASH_IV

        # 1. Sort dictionary keys alphabetically (ASCII order)
        sorted_keys = sorted(params.keys())
        
        # 2. Join parameters as key=value&key2=value2...
        raw_str = f"HashKey={hash_key}&" + "&".join([f"{k}={params[k]}" for k in sorted_keys]) + f"&HashIV={hash_iv}"
        
        # 3. URL encode string
        encoded_str = urllib.parse.quote_plus(raw_str).lower()
        
        # 4. ECPay specific character replacements
        encoded_str = (
            encoded_str
            .replace('%2d', '-')
            .replace('%5f', '_')
            .replace('%2e', '.')
            .replace('%21', '!')
            .replace('%2a', '*')
            .replace('%28', '(')
            .replace('%29', ')')
        )

        # 5. SHA256 hash & uppercase
        check_mac_val = hashlib.sha256(encoded_str.encode('utf-8')).hexdigest().upper()
        return check_mac_val

    @classmethod
    def create_checkout_params(cls, order_number, amount, item_name, return_url, client_back_url=None):
        now_str = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
        params = {
            "MerchantID": cls.SANDBOX_MERCHANT_ID,
            "MerchantTradeNo": str(order_number),
            "MerchantTradeDate": now_str,
            "PaymentType": "aio",
            "TotalAmount": str(int(amount)),
            "TradeDesc": "ShowOnMove Points Topup",
            "ItemName": str(item_name),
            "ReturnURL": str(return_url),
            "ChoosePayment": "ALL",
            "EncryptType": "1",
        }
        if client_back_url:
            params["ClientBackURL"] = str(client_back_url)

        params["CheckMacValue"] = cls.generate_check_mac_value(params)
        return {
            "checkout_url": cls.SANDBOX_CHECKOUT_URL,
            "params": params,
        }

    @classmethod
    def verify_check_mac_value(cls, post_data, hash_key=None, hash_iv=None):
        if "CheckMacValue" not in post_data:
            return False
        received_mac = post_data["CheckMacValue"]
        params = {k: v for k, v in post_data.items() if k != "CheckMacValue"}
        calc_mac = cls.generate_check_mac_value(params, hash_key, hash_iv)
        return received_mac == calc_mac
