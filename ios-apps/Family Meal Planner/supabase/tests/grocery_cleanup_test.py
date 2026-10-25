"""Disposable Docker database only; real migration schema, synthetic rows.
Run after 001, 003, 005, 015 in a fresh network-isolated container named
fluffylist-grocery-validation. No production URL or credentials are accepted.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HOUSEHOLD = '20000000-0000-0000-0000-000000000001'

def sql(source, succeeds=True):
    result = subprocess.run([
        'docker', 'exec', '-i', '-e', 'PGPASSWORD=fluffylist_local_test',
        'fluffylist-grocery-validation', 'psql', '-h', '127.0.0.1',
        '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At'
    ], input=source, text=True, capture_output=True)
    if (result.returncode == 0) != succeeds:
        raise AssertionError(result.stdout + result.stderr)
    return result.stdout.strip()

sql("""
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001');
insert into households(id,owner_id) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001');
insert into meal_plans(id,household_id,date) values
('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026-10-25');
insert into grocery_items(household_id,name,quantity,unit,note,is_checked,created_at)
select '20000000-0000-0000-0000-000000000001',name,quantity,unit,note,is_checked,at::timestamptz
from (values
('[For the Pork] extra-virgin olive oil',2.,'tbsp',null,false,'2026-10-24'),
('olive oil',1.,'cup',null,false,'2026-10-25'),
('olive oil (divided)',2.,'tbsp',null,false,'2026-10-25'),
('arrowroot flour (or tapioca flour)',2.,'tsp',null,false,'2026-10-24'),
('arrowroot flour or tapioca',2.,'tsp',null,false,'2026-10-25'),
('arrowroot flour',1.,'tsp',null,false,'2026-10-25'),
('tapioca flour',1.,'tsp',null,false,'2026-10-25'),
('extra-virgin olive oil, Clarified Butter, or ghee',1.,'cup',null,false,'2026-10-25'),
('For the Filling',1.,'piece',null,false,'2026-10-25'),
('[For the Slaw]',1.,'piece',null,false,'2026-10-25'),
('garlic',2.,'clove',null,false,'2026-10-25'),
('garlic',1.,'tsp',null,false,'2026-10-25'),
('tomatoes',1.,'can','14 ounces',false,'2026-10-25'),
('tomatoes',1.,'can','28 ounces',false,'2026-10-25'),
('cilantro',1.,'piece','2 tbsp',false,'2026-10-25'),
('cilantro',1.,'piece','2 tbsp',false,'2026-10-25'),
('[For the Pork] olive oil',1.,'cup',null,true,'2026-10-25')
) as v(name,quantity,unit,note,is_checked,at);
insert into grocery_items(household_id,name,quantity,unit) values
('20000000-0000-0000-0000-000000000002','For the Filling',1,'piece');
insert into grocery_contributions(grocery_item_id,meal_plan_id,quantity)
select id,'30000000-0000-0000-0000-000000000001',case unit when 'cup' then 0.5 else 1.5 end
from grocery_items where name in ('[For the Pork] extra-virgin olive oil','olive oil');
insert into grocery_contributions(grocery_item_id,meal_plan_id,quantity)
select id,'30000000-0000-0000-0000-000000000001',1 from grocery_items
where name='For the Filling' and household_id='20000000-0000-0000-0000-000000000001';
""")

sql("""
insert into grocery_contributions(grocery_item_id,meal_plan_id,quantity)
select id,'30000000-0000-0000-0000-000000000001',1 from grocery_items
where name in ('arrowroot flour (or tapioca flour)', 'arrowroot flour or tapioca', 'olive oil (divided)');
""")

snapshot = "select jsonb_build_object('items',(select jsonb_agg(to_jsonb(g) order by id) from grocery_items g),'links',(select jsonb_agg(to_jsonb(c) order by id) from grocery_contributions c));"
before = sql(snapshot)
cleanup = (ROOT/'scripts/cleanup_groceries.sql').read_text().replace('HOUSEHOLD_ID',HOUSEHOLD)
sql(cleanup)  # dry run must have no persistent effects
assert sql(snapshot) == before
sql(cleanup.replace('ROLLBACK;', 'COMMIT;'))
assert sql("select quantity from grocery_items where name='extra-virgin olive oil'") == '20'
assert sql("select count(*) from grocery_contributions") == '5'
assert sql("select sum(quantity) from grocery_contributions") == '12.5'
assert sql("select count(*) from grocery_items where name='garlic'") == '2'
assert sql("select count(*) from grocery_items where name='tomatoes'") == '2'
assert sql("select count(*) from grocery_items where name='cilantro'") == '2'
assert sql("select count(*) from grocery_items where name='For the Filling'") == '1'
assert sql("select name from grocery_items where is_checked") == '[For the Pork] olive oil'
assert sql("select has_schema_privilege('authenticated','fluffylist_maintenance','USAGE')") == 'f'
assert sql("select quantity from grocery_items where name='arrowroot flour (or tapioca flour)'") == '4'
assert sql("select count(*) from grocery_items where name='arrowroot flour or tapioca'") == '0'
assert sql("select quantity from grocery_items where name='arrowroot flour'") == '1'
assert sql("select quantity from grocery_items where name='tapioca flour'") == '1'
assert sql("select quantity from grocery_items where name='extra-virgin olive oil, Clarified Butter, or ghee'") == '1'
after = sql(snapshot)
recovery_id = sql('select id from fluffylist_maintenance.grocery_cleanup')
restore = (ROOT/'scripts/restore_groceries.sql').read_text().replace('RECOVERY_ID', recovery_id)
sql("update grocery_items set quantity=19 where name='extra-virgin olive oil'")
sql(restore, succeeds=False)  # must not erase changes made after cleanup
assert sql("select quantity from grocery_items where name='extra-virgin olive oil'") == '19'
sql("update grocery_items set quantity=20 where name='extra-virgin olive oil'")
sql(restore)
assert sql(snapshot) == before  # exact IDs, names, notes, dates, quantities, links
sql(cleanup.replace('ROLLBACK;', 'COMMIT;'))
assert sql(snapshot) == after
sql(cleanup.replace('ROLLBACK;', 'COMMIT;'))
assert sql(snapshot) == after  # rerunning is idempotent
# Simulate the existing service subtracting this meal's contributions.
sql("update grocery_items g set quantity=g.quantity-c.quantity from (select grocery_item_id,sum(quantity) quantity from grocery_contributions group by grocery_item_id) c where g.id=c.grocery_item_id")
assert sql("select quantity from grocery_items where name='extra-virgin olive oil'") == '9.5'
assert sql("select quantity from grocery_items where name='arrowroot flour (or tapioca flour)'") == '2'
print('PASS: alternatives and divided normalization,  dry run, unit conversion, contribution IDs/amounts, checked rows, other household, incompatible units/notes, exact recovery, stale recovery refusal, idempotence, meal unwind')
