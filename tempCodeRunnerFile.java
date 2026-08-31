import java.util.ArrayList; // ArrayList প্যাকেজ ইম্পোর্ট করা হলো

public class WarehouseInventory {
    public static void main(String[] args) {
        
        // ১. fruitStock নামক ArrayList তৈরি এবং প্রাথমিক ফলগুলো যোগ করা
        ArrayList<String> fruitStock = new ArrayList<>();
        fruitStock.add("Banana"); // Index 0
        fruitStock.add("Orange"); // Index 1
        fruitStock.add("Lychee"); // Index 2
        fruitStock.add("Mango");  // Index 3
        fruitStock.add("Apple");  // Index 4
        
        System.out.println("1. Initial Stock: " + fruitStock);

        // ২. নতুন শিপমেন্ট: index 2 থেকে Pear, Grape, Date ইনসার্ট করা
        // (এখানে index 2 তে পিয়ার বসবে এবং বাকিগুলো ডানে শিফট হবে)
        fruitStock.add(2, "Pear");
        fruitStock.add(3, "Grape");
        fruitStock.add(4, "Date");
        System.out.println("2. After new shipment: " + fruitStock);

        // ৩. "Apple"-কে রিমুভ করে "Rotten Apple" দিয়ে রিপ্লেস করা
        int appleIndex = fruitStock.indexOf("Apple");
        if (appleIndex != -1) {
            fruitStock.set(appleIndex, "Rotten Apple");
        }
        System.out.println("3. After replacing Apple: " + fruitStock);

        // ৪. প্রথম তিনটি ফল ডেলিভারি ট্রাকে লোড করা (Extract, Print এবং Remove করা)
        System.out.println("\n4. Loading first 3 fruits to delivery truck:");
        for (int i = 0; i < 3; i++) {
            String removedFruit = fruitStock.remove(0); // প্রতিবার প্রথম উপাদান রিমুভ হবে
            System.out.println("Loaded to truck: " + removedFruit);
        }
        System.out.println("Remaining Stock after loading: " + fruitStock);

        // ৫. চেক করা লিস্টে "Mango" আছে কি না এবং তার ইনডেক্স প্রিন্ট করা
        if (fruitStock.contains("Mango")) {
            System.out.println("5. Mango found at index: " + fruitStock.indexOf("Mango"));
        } else {
            System.out.println("5. Out of Stock");
        }

        // ৬. fruitStock-এর প্রথম এবং শেষ আইটেম ডিসপ্লে করা
        System.out.println("6. First item in stock: " + fruitStock.get(0));
        System.out.println("   Last item in stock: " + fruitStock.get(fruitStock.size() - 1));

        // ৭. fruitStock-এর সাইজ ডিসপ্লে করা এবং তারপর clear করা
        System.out.println("7. Current size of fruitStock: " + fruitStock.size());
        fruitStock.clear();
        System.out.println("   Stock cleared. Current size: " + fruitStock.size());
    }
}