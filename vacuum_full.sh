#!/bin/bash
dbname="odoo"
dbport="5432"
dbfolder="16/data/base"
# ini adalah mount point yang ditempati database untuk mengetahui sisa disk
dfmount="/"

[ -d vacuum_full ] || mkdir vacuum_full
echo "$(date) VACUUM FULL semua tabel berukuran lebih dari 1 juta bytes (~1GB) mulai dari yang terkecil"
dbsize=`du -s $dbfolder | awk '{print $1}'`
echo "Besar database awal: $dbsize kB"
#tabs="dym_stock_opname_tools_count_line_filter"
tabs=`psql -At -p $dbport -c "with my_tables as (select relname, pg_total_relation_size(quote_ident(relname)) as relsize from pg_stat_user_tables) select relname from my_tables where relsize >= 1000000000 order by relsize" $dbname`
dbsize2="0"
awal=$SECONDS
for tab in $tabs
do
    # Jika sudah jam 5 pagi maka vacuum full dihentikan
    jam="$(date +'%H')"
    if (( jam >= 5 )); then
        echo "$(date) VACUUM FULL dihentikan karena sudah jam 5 pagi"
        break
    fi
    # Jika sisa disk tidak cukup maka vacuum full dibatalkan
    sisa=`df | grep $dfmount | awk '{print $4}'`
    sisa=`echo "$sisa * 1024" | bc`
    tabsize=`psql -At -p $dbport -c "select pg_total_relation_size('$tab')" $dbname`
    cek=`echo "$sisa < $tabsize" | bc`
    if [ "$cek" = "1" ]; then
        kurang=`echo "$tabsize - $sisa" | bc`
        echo "$(date) Vacuum Full tabel $tab BATAL karena disk tidak cukup, perlu $tabsize bytes, hanya tersedia $sisa bytes, kurang $kurang bytes"
        continue
    fi
    # Jika tidak ada vacuum atau autovacuum maka vacuum full dilakukan
    if psql -p $dbport -c "SELECT pid FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND query LIKE '%$tab%' AND query ILIKE '%vacuum%'" $dbname | grep '0 rows' > /dev/null
    then
        mulai=$SECONDS
        dbsize1=`du -s $dbfolder | awk '{print $1}'`
        # Stop semua query ke tabel ini sebelum vacuum
        psql -p $dbport -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND query LIKE '%$tab%'" $dbname > /dev/null
        #psql -p $dbport -c "VACUUM (FULL, VERBOSE, ANALYZE) $tab" $dbname > vacuum_full/$tab.log 2>&1
        dbsize2=`du -s $dbfolder | awk '{print $1}'`
        echo "$(date) Vacuum Full tabel $tab sukses dengan durasi $(( SECONDS - mulai )) detik, mengurangi $(( dbsize1 - dbsize2 )) kB"
    else
        echo "$(date) Vacuum Full tabel $tab BATAL karena ada vacuum/autovacuum pada tabel ini."
    fi
done
if [ "$dbsize2" != "0" ]
then
    echo "$(date) VACUUM FULL sukses dengan durasi $(( SECONDS - awal )) detik, mengurangi $(( dbsize - dbsize2 )) kB"
    echo "Besar database akhir: $dbsize2 kB"
fi

