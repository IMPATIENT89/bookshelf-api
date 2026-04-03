class CreateAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :authors do |t|
      t.string :first_name, limit: 100, null: false
      t.string :last_name, limit: 100, null: false
      t.text :bio
      t.integer :birth_year
      t.integer :death_year
      t.string :website

      t.timestamps
    end

    add_index :authors, [ :last_name, :first_name ]
  end
end
