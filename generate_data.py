"""
Datengenerator für dbt Portfolio Projekt
Generiert realistische E-Commerce/SaaS Daten mit absichtlichen Datenqualitätsproblemen
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

# Seed für Reproduzierbarkeit
random.seed(42)

def random_date(start_date, end_date):
    """Generiert ein zufälliges Datum zwischen start und end"""
    time_between = end_date - start_date
    days_between = time_between.days
    random_days = random.randrange(days_between)
    return start_date + timedelta(days=random_days)

def generate_customers(num_customers=500):
    """Generiert Kundendaten mit absichtlichen Datenfehlern"""

    first_names = ['Max', 'Anna', 'Thomas', 'Sarah', 'Michael', 'Julia', 'David', 'Laura',
                   'Daniel', 'Lisa', 'Stefan', 'Maria', 'Peter', 'Emma', 'Felix']
    last_names = ['Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner',
                  'Becker', 'Schulz', 'Hoffmann', 'Koch', 'Bauer', 'Richter', 'Klein']

    countries = ['Germany', 'Austria', 'Switzerland', 'Netherlands', 'Belgium']
    tiers = ['Free', 'Basic', 'Premium', 'Enterprise']

    customers = []
    start_date = datetime(2022, 1, 1)
    end_date = datetime(2024, 12, 31)

    for i in range(1, num_customers + 1):
        customer = {
            'customer_id': i,
            'first_name': random.choice(first_names),
            'last_name': random.choice(last_names),
            'signup_date': random_date(start_date, end_date).strftime('%Y-%m-%d'),
            'country': random.choice(countries),
            'subscription_tier': random.choice(tiers)
        }

        # Absichtliche Datenfehler einbauen
        if random.random() < 0.05:  # 5% NULL-Werte bei country
            customer['country'] = ''

        if random.random() < 0.03:  # 3% inkonsistente Datumsformate
            customer['signup_date'] = random_date(start_date, end_date).strftime('%d.%m.%Y')

        if random.random() < 0.02:  # 2% fehlende Namen
            customer['first_name'] = ''

        customers.append(customer)

    return customers

def generate_orders(customers, avg_orders_per_customer=3):
    """Generiert Bestelldaten basierend auf Kunden"""

    statuses = ['completed', 'pending', 'cancelled', 'refunded']
    orders = []
    order_id = 1

    start_date = datetime(2022, 1, 1)
    end_date = datetime(2024, 12, 31)

    for customer in customers:
        # Anzahl der Bestellungen variiert
        num_orders = random.choices(
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 15],
            weights=[10, 15, 20, 20, 15, 10, 5, 3, 1, 0.5, 0.5]
        )[0]

        customer_signup = datetime.strptime(
            customer['signup_date'] if '-' in customer['signup_date']
            else datetime.strptime(customer['signup_date'], '%d.%m.%Y').strftime('%Y-%m-%d'),
            '%Y-%m-%d'
        ) if customer['signup_date'] else start_date

        for _ in range(num_orders):
            # Bestellungen nur nach Signup-Datum
            order_date = random_date(customer_signup, end_date)

            # Betrag abhängig von Subscription Tier
            tier_multiplier = {
                'Free': 0.5,
                'Basic': 1.0,
                'Premium': 2.5,
                'Enterprise': 5.0
            }

            base_amount = random.uniform(10, 500)
            tier = customer.get('subscription_tier', 'Basic')
            amount = base_amount * tier_multiplier.get(tier, 1.0)

            order = {
                'order_id': order_id,
                'customer_id': customer['customer_id'],
                'order_amount': round(amount, 2),
                'created_at': order_date.strftime('%Y-%m-%d %H:%M:%S'),
                'order_status': random.choice(statuses)
            }

            # Absichtliche Datenfehler
            if random.random() < 0.04:  # 4% negative Beträge (Fehler)
                order['order_amount'] = -abs(order['order_amount'])

            if random.random() < 0.03:  # 3% NULL-Status
                order['order_status'] = ''

            if random.random() < 0.02:  # 2% inkonsistente Datumsformate
                order['created_at'] = order_date.strftime('%d/%m/%Y')

            orders.append(order)
            order_id += 1

    return orders

def generate_payments(orders):
    """Generiert Payment-Daten basierend auf Bestellungen"""

    payment_methods = ['credit_card', 'paypal', 'bank_transfer', 'sepa', 'invoice']
    payment_statuses = ['success', 'failed', 'pending', 'refunded']

    payments = []
    payment_id = 1

    for order in orders:
        # Nicht jede Bestellung hat ein Payment (absichtlicher Fehler)
        if random.random() < 0.95:  # 95% haben Payment

            # Payment-Status korreliert mit Order-Status
            if order['order_status'] == 'completed':
                status = random.choices(
                    payment_statuses,
                    weights=[90, 2, 5, 3]
                )[0]
            elif order['order_status'] == 'cancelled':
                status = random.choices(
                    payment_statuses,
                    weights=[5, 70, 10, 15]
                )[0]
            else:
                status = random.choice(payment_statuses)

            payment = {
                'payment_id': payment_id,
                'order_id': order['order_id'],
                'payment_method': random.choice(payment_methods),
                'payment_status': status,
                'payment_amount': order['order_amount']
            }

            # Absichtliche Datenfehler
            if random.random() < 0.03:  # 3% Payment-Betrag stimmt nicht mit Order überein
                payment['payment_amount'] = round(order['order_amount'] * random.uniform(0.5, 1.5), 2)

            if random.random() < 0.02:  # 2% Duplikate (mehrere Payments pro Order)
                payments.append(payment.copy())
                payment_id += 1

            payments.append(payment)
            payment_id += 1

    return payments

def save_to_csv(data, filename, fieldnames):
    """Speichert Daten als CSV"""
    seeds_dir = Path(__file__).parent / 'seeds'
    seeds_dir.mkdir(exist_ok=True)

    filepath = seeds_dir / filename

    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)

    print(f"✓ {filename} erstellt mit {len(data)} Zeilen")

def main():
    print("Generiere E-Commerce/SaaS Daten für dbt Portfolio Projekt...\n")

    # 1. Kunden generieren
    customers = generate_customers(500)
    save_to_csv(
        customers,
        'raw_customers.csv',
        ['customer_id', 'first_name', 'last_name', 'signup_date', 'country', 'subscription_tier']
    )

    # 2. Bestellungen generieren
    orders = generate_orders(customers)
    save_to_csv(
        orders,
        'raw_orders.csv',
        ['order_id', 'customer_id', 'order_amount', 'created_at', 'order_status']
    )

    # 3. Payments generieren
    payments = generate_payments(orders)
    save_to_csv(
        payments,
        'raw_payments.csv',
        ['payment_id', 'order_id', 'payment_method', 'payment_status', 'payment_amount']
    )

    print(f"\n✓ Datengenerierung abgeschlossen!")
    print(f"  - {len(customers)} Kunden")
    print(f"  - {len(orders)} Bestellungen")
    print(f"  - {len(payments)} Payments")
    print("\nAbsichtliche Datenfehler eingebaut:")
    print("  - NULL-Werte in verschiedenen Feldern")
    print("  - Inkonsistente Datumsformate")
    print("  - Negative Beträge")
    print("  - Fehlende Payments")
    print("  - Payment/Order Betrag-Diskrepanzen")

if __name__ == '__main__':
    main()
