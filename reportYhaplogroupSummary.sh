#!/bin/bash

gapPenaltyForDamage=4
gapPenaltyForOneDerivedNonDamageRead=6

maximumTMRCAforGapPenalty=10800
yearsPerPointPenalty=180
minimumYearsForGapPenaltyForNonDamage=1200
minimumYearsForGapPenaltyForDamage=900

maximumIgnoredAncestralsForTerminalDamage=3

doNotBreakTies=0

sampleAge=0

function usage()
{
    >&2 echo "usage: reportYhaplogroupSummary.sh "
    >&2 echo "       [--gapPenaltyForDamage integer number of haplogroups skipped before the penalty for aDNA damage is applied to the score (default $gapPenaltyForDamage)]" 
    >&2 echo "       [--gapPenaltyForOneDerivedNonDamageRead (default $gapPenaltyForOneDerivedNonDamageRead)]"
    >&2 echo "       [--maximumTMRCAforGapPenalty TMRCA year below which gap penalty can be applied (default $maximumTMRCAforGapPenalty)]"
    >&2 echo "       [--yearsPerPointPenalty subtract 1 point from the score for these number of gap years between derived haplogroups (default $yearsPerPointPenalty)]"
    >&2 echo "       [--minimumYearsForGapPenaltyForNonDamage apply the gap penalty for cases equal or above the minimum number of years in the gap between derived haplogroups where the downstream one is not aDNA damage (default $minimumYearsForGapPenaltyForNonDamage)] " 
    >&2 echo "       [--minimumYearsForGapPenaltyForDamage apply the gap penalty for cases equal or above the minimum number of years in the gap between derived haplogroups where the downstream one is aDNA damage (default $minimumYearsForGapPenaltyForDamage)]"
    >&2 echo "       [--maximumIgnoredAncestralsForTerminalDamage the maximum number of ancestral SNPs for a haplogroup allowed before they are subtracted from the score (default $maximumIgnoredAncestralsForTerminalDamage)]"
    <&2 echo "       [--doNotBreakTies do not break tied top scores of haplogroups by raising the scores of non-aDNA damage haplogroups"
    <&2 echo "       and then raising the score of the common upstream derived haplogroup for the remaining tied score haplogroups (default break ties)]"
    <&2 echo "       [--sampleAge the archaeological age of the sample in years before the year 2000.  if the sample age is given, then all derived haplogroups  with a formed date (the TMRCA of the immediate parent of the haplogroup) later than the given age of the sample have their score set to zero."
    >&2 echo "       [-h|--help] [.tsv file | stdin (default)]"
}

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

TMRCALookupTable=${INSTALL_DIR}/tree/haplogroupTMRCAtable.tsv

while [ "$1" != "" ]; do
   case $1 in
        -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
            usage
            exit
            ;;
        --gapPenaltyForDamage)
            gapPenaltyForDamage=$2

            if [[ "$gapPenaltyForDamage" =~ ^[0-9]+$ ]] && (( $gapPenaltyForDamage > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --gapPenaltyForOneDerivedNonDamageRead)
            gapPenaltyForOneDerivedNonDamageRead=$2
            if [[ "$gapPenaltyForOneDerivedNonDamageRead" =~ ^[0-9]+$ ]] && (( $gapPenaltyForOneDerivedNonDamageRead > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --maximumIgnoredAncestralsForTerminalDamage)    
            maximumIgnoredAncestralsForTerminalDamage=$2
            if [[ "$maximumIgnoredAncestralsForTerminalDamage" =~ ^[0-9]+$ ]] && (( $maximumIgnoredAncestralsForTerminalDamage > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --maximumTMRCAforGapPenalty)    
            maximumTMRCAforGapPenalty=$2
            if [[ "$maximumTMRCAforGapPenalty" =~ ^[0-9]+$ ]] && (( $maximumTMRCAforGapPenalty > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --yearsPerPointPenalty)    
            yearsPerPointPenalty=$2
            if [[ "$yearsPerPointPenalty" =~ ^[0-9]+$ ]] && (( $yearsPerPointPenalty > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --minimumYearsForGapPenaltyForNonDamage)    
            minimumYearsForGapPenaltyForNonDamage=$2
            if [[ "$minimumYearsForGapPenaltyForNonDamage" =~ ^[0-9]+$ ]] && (( $minimumYearsForGapPenaltyForNonDamage > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --minimumYearsForGapPenaltyForDamage)    
            minimumYearsForGapPenaltyForDamage=$2
            if [[ "$minimumYearsForGapPenaltyForDamage" =~ ^[0-9]+$ ]] && (( $minimumYearsForGapPenaltyForDamage > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
         --sampleAge)    
            sampleAge=$2
            if [[ "$sampleAge" =~ ^[0-9]+$ ]] && (( $sampleAge > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        --doNotBreakTies)
            doNotBreakTies=1
            ;; 
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            usage
            exit 1
            ;;
        *)
            break
   esac
   shift
done

input="-"

if [ -f "$1" ] && [ "${1: -4}" == ".tsv" ]
then
   input="${1}"
else if [ "${1}" != "" ]
     then
        >&2 echo "cannot open ${1} or it is not a valid .tsv file."
         usage
        exit 1
     fi
fi

cat "$input" | awk -v paths="$paths" -v TMRCA_lookup_table=$TMRCALookupTable -v gap_penalty_for_damage=$gapPenaltyForDamage -v gap_limit_for_damage=$gapLimitForDamage -v gap_penalty_for_one_derived_non_damage_read=$gapPenaltyForOneDerivedNonDamageRead -v maximum_TMRCA_for_gap_penalty=$maximumTMRCAforGapPenalty -v years_per_point_penalty=$yearsPerPointPenalty -v minimum_years_for_gap_penalty_for_non_damage=$minimumYearsForGapPenaltyForNonDamage -v minimum_years_for_gap_penalty_for_damage=$minimumYearsForGapPenaltyForDamage -v maximum_ignored_ancestrals_for_terminal_damage=$maximumIgnoredAncestralsForTerminalDamage -v do_not_break_ties=$doNotBreakTies -v sample_age=$sampleAge '
BEGIN {
  FS=OFS="\t"; 

  while (( getline line < TMRCA_lookup_table) > 0 ) 
  {
     split(line, fields)
     TMRCAlookup[fields[1]] = fields[2]+0
  }

  old_haplogroup = ""
  old_total_reads = 0
  old_derived_reads = 0
  old_ancestral_allele = ""
  old_derived_allele = ""
  old_genotype = ""
  snps = 0;
  total_derived_reads = 0
  total_ancestral_reads = 0
  terminal_derived = 0

  derived_read_ancestral_allele = ""
  derived_read_genotype = ""
  ancestral_read_derived_allele ""
  ancestral_read_genotype = ""

  aDNA_damage = ""

  stored_derived = 0
  stored_snps = 0
  stored_derived_reads = 0
  stored_aDNA_damage = ""
  stored_upstream_derived_haplogroup = ""
  stored_upstream_intervening_ancestral = ""
  stored_short_path = ""
  stored_gap_years = 0
  stored_full_path = ""
  stored_haplogroup = " "

  states[""] = "-"
  deriveds[""] = 0
  total_snps[""] = 0
  total_derived_reads_for_haplogroup[""] = 0
  aDNA_damages[""] = ""
  scores[""] = 0
  recalculated_scores[""] = 0
  derived_terminals_below_all_aDNA_damages[""] = 0
  upstream_intervening_ancestrals[""] = ""
  gap_from_upstream_derived_haplogroups[""] = 0
  gap_years_from_upstream_derived_haplogroup[""] = 0
  formed_dates[""] = 0
  short_paths[""] = ""
  terminal_deriveds[""] = 0

  total_haplogroups_below_not_aDNA_damages[""] = 0

  #initialize empty arrays is a POSIX compatible way
  split("", derived_haplogroups)
  split("", upstream_derived_haplogroups)
  split("", haplogroup_blacklist)
  split("", haplogroups_by_path)
  split("", downstream_derived_counts)
  split("", downstream_derived_not_damage_counts)
  split("", downstream_non_aDNA_damage_derived_terminals)
}

function add_haplogroup_to_blacklist(haplogroup)
{
    if (haplogroup != "")
    {
       haplogroup_blacklist[haplogroup] = ""
    }      
}

function find_upstream_blacklisted_haplogroup(full_path,   i, upstream_haplogroups)
{
    split(full_path, upstream_haplogroups, ">")

    for (i = 1; i < length(upstream_haplogroups); i++)
    {
       if (upstream_haplogroups[i] in haplogroup_blacklist)
       {
           return upstream_haplogroups[i]
       }
    }

   return ""
}

function find_upstream_intervening_ancestral(short_path,   i, n, haplogroups)
{
   if (short_path == "JK>HIJK>IJK>IJ>I")
   {
      return ""
   }

   gsub(/^[^>]*/, "", short_path)
   gsub(/^>/, "", short_path)

   gsub(/[^>]*$/, "", short_path)
   gsub(/>$/, "", short_path)

   n = split(short_path, haplogroups, ">")

   if (length(haplogroups) > 0)
   {
      for (i =1; i <= length(haplogroups); i++)
      {
         if (haplogroups[i] in deriveds && deriveds[haplogroups[i]] == 0 && haplogroups[i] in aDNA_damages && aDNA_damages[haplogroups[i]] == "False")
         {
            return haplogroups[i]
         }
      }
   } 

   return ""
}


function find_upstream_derived_haplogroup(path,   i, n, haplogroups)
{
   n = split(path, haplogroups, ">")
   delete haplogroups[n]

   for (i = n-1; i > 0; i--)
   {
      if (haplogroups[i] in derived_haplogroups)
      {
         return haplogroups[i]
      }
   }
   
   return ""
}

function calculate_short_path(full_path)
{
   return substr(full_path, index(full_path, (find_upstream_derived_haplogroup(full_path) ">")))
}

function calculate_gap_years(upstream_haplogroup, haplogroup)
{
   if (upstream_haplogroup != "" && haplogroup != "")
   {
      return TMRCAlookup[upstream_haplogroup] - TMRCAlookup[haplogroup]
   }
   else
   { 
      return 0
   } 
}

function store_derived_haplogroup(derived, snps, derived_reads, aDNA_damage, full_path, haplogroup)
{
   stored_derived = derived
   stored_snps = snps
   stored_derived_reads = derived_reads
   stored_aDNA_damage = aDNA_damage
   stored_full_path = full_path
   stored_haplogroup = haplogroup

   stored_short_path = calculate_short_path(full_path)
   stored_upstream_derived_haplogroup = find_upstream_derived_haplogroup(stored_short_path)
   stored_gap_years = calculate_gap_years(stored_upstream_derived_haplogroup, haplogroup)
   stored_upstream_intervening_ancestral = find_upstream_intervening_ancestral(stored_short_path) 

   derived_haplogroups[haplogroup] = aDNA_damage
}

function is_qualified_for_gap_penalty(haplogroup)
{
   # apply penalty only for those derived haplogroups under a certain age and which have non-zero TMRCAs or are terminal

   if ((TMRCAlookup[haplogroup] > 0 || terminal_deriveds[haplogroup] == 1) && TMRCAlookup[haplogroup] <= maximum_TMRCA_for_gap_penalty)
   {
      if (aDNA_damages[haplogroup] == "False" && total_derived_reads_for_haplogroup[haplogroup] == 1)
      {
         if (gap_from_upstream_derived_haplogroups[haplogroup] >= gap_penalty_for_one_derived_non_damage_read && gap_years_from_upstream_derived_haplogroup[haplogroup] >= minimum_years_for_gap_penalty_for_non_damage)
         {
            return 1
         }
      }
      else if (aDNA_damages[haplogroup] == "True")
      {
         if (terminal_deriveds[haplogroup] == 1)
         {
            if (gap_from_upstream_derived_haplogroups[haplogroup] >= gap_penalty_for_damage && gap_years_from_upstream_derived_haplogroup[haplogroup] >=  minimum_years_for_gap_penalty_for_damage)             
            {
               return 1
            }
         }
      }
   }

   return 0
}

function calculate_score(haplogroup)
{
   # score 0 for ancestral haplogroup

   if (states[haplogroup]== "-")
   {
      scores[haplogroup] = 0
      return scores[haplogroup]
   }
   
   # if the sample age is given, score 0 for the haplogroup if the formed date 
   # of the haplogroup is younger than the sample age
   
   if (sample_is_older_than_formed_date_of_haplogroup(haplogroup))
   {
      scores[haplogroup] = 0
      terminal_deriveds[haplogroup] = 0
      
      return scores[haplogroup]   
   }

   # calculate scores for derived haplogroups:

   # if a haplogroup has only one non-aDNA damage derived read and  the gap from the upstream derived haplogroup is
   # greater than or equal to the parameter for the gap penalty for such a haplogroup, then a gap penalty is applied 
   # to make the score less than the upstream derived haplogroup because it is likely to be aDNA damage

   if (is_qualified_for_gap_penalty(haplogroup))
   {
      scores[haplogroup] = scores[upstream_derived_haplogroups[haplogroup]] - int((gap_years_from_upstream_derived_haplogroup[haplogroup]+0.5) / years_per_point_penalty)

      return scores[haplogroup]
   }

   # the score for a terminal derived haplogroup that is not aDNA_damage is the sum of the upstream derived haplogroup score plus
   # the number of derived SNPs. No subtraction of ancestral SNPs because it may be a split:
   
   if (terminal_deriveds[haplogroup] == 1 && aDNA_damages[haplogroup] == "False")
   {
      if (haplogroup in upstream_derived_haplogroups)
      {
         downstream_non_aDNA_damage_derived_terminals[upstream_derived_haplogroups[haplogroup]]++
      }

      scores[haplogroup] = scores[upstream_derived_haplogroups[haplogroup]] + deriveds[haplogroup]
      return scores[haplogroup]
   }

   # the score for a non-terminal haplogroup is the sum of the upstream derived haplogroup score plus the derived SNPs minus the 
   # ancestral SNPs and minus the ancestral SNPs of any upstream intervening ancestral haplogroup. 
   # This is true of it is aDNA damage or not, since there is already a derived haplogroup with no aDNA damage below

   if (terminal_deriveds[haplogroup] == 0)
   {
      if (upstream_derived_haplogroups[haplogroup] != "")
      {
         scores[haplogroup] = scores[upstream_derived_haplogroups[haplogroup]] + (deriveds[haplogroup] - (total_snps[haplogroup] - deriveds[haplogroup]))

         if (aDNA_damages[upstream_intervening_ancestrals[haplogroup]] == "False")
         {
            scores[haplogroup] -= total_snps[upstream_intervening_ancestrals[haplogroup]]
         }
      } 
      else
      {
         # at the root of the tree

         scores[haplogroup] = deriveds[haplogroup] - (total_snps[haplogroup] - deriveds[haplogroup])
      }

      return scores[haplogroup]
   }

   # if a terminal is aDNA damage and it has an intervening ancestral haplogroup after the previous upstream derived haplogroup 
   # then the intervening ancestral SNP total is added to the ancestral SNPs for that haplogroup for debiting.

   # If there are no other derived haplogroups under the previous upstream derived haplogroup that are not aDNA damage, then the previous upstream derived haplogroup then becomes the terminal and the score for that is recalculated:

   if (terminal_deriveds[haplogroup] == 1 && aDNA_damages[haplogroup] == "True" &&  upstream_intervening_ancestrals[haplogroup] != "" && aDNA_damages[upstream_intervening_ancestrals[haplogroup]] == "False")
   {
      scores[haplogroup] = scores[upstream_derived_haplogroups[haplogroup]] + (deriveds[haplogroup] - (total_snps[haplogroup] - deriveds[haplogroup]))

      scores[haplogroup] -= total_snps[upstream_intervening_ancestrals[haplogroup]]

      return scores[haplogroup]         
   }  
  
   # If the terminal is aDNA_damage and it has no intervening ancestral haplogroup after the previous upstream derived haplogroup 
   # then the score is *temporarily* the score of the upstream derived haplogroup minus one, until recalculation

   if (terminal_deriveds[haplogroup] == 1 && aDNA_damages[haplogroup] == "True" && upstream_intervening_ancestrals[haplogroup] == "")
   {
      # if the terminal that is aDNA_damage has a gap from the upstream derived haplogroup >= the gap_limit_for_damage parameter for this run 
      # then the score is set to 0

      # if the terminal that is aDNA_damage has a gap from the upstream derived haplogroup < the gap_limit_for_damage parameter for this run
      # and the gap is >= the gap_penalty_for_damage parameter for this run then the score is set to the score for the upstream derived haplogroup
      # minus the gap value+1. This is to prevent any terminal with aDNA damage from equaling or exceeding the score of the 
      # upstream derived haplogroup.

       if ((total_snps[haplogroup]-deriveds[haplogroup]) <= maximum_ignored_ancestrals_for_terminal_damage)
       { 
          scores[haplogroup] = scores[upstream_derived_haplogroups[haplogroup]] + deriveds[haplogroup]
       }
       else
       {
          scores[haplogroup] = scores[upstream_derived_haplogroups[haplogroup]] + (deriveds[haplogroup] - (total_snps[haplogroup] - deriveds[haplogroup]))
       }

       return scores[haplogroup]
   }
}

function find_upstream_non_damage_derived_haplogroup_with_all_damage_descendants(terminal_haplogroup)
{

}

function recalculate_tree_below_haplogroup(haplogroup)
{

}

function recalculate_scores(   terminal_haplogroup, upstream_derived_haplogroup)
{
   # if a derived haplogroup is not a terminal derived haplogroup and all downstream derived haplogroups are aDNA damage then
   # treat it as a terminal derived haplogroup for scoring, where the score is the score of the upstream ancestral plus the 
   # derived SNPs without subtracting the ancestral SNPs. In other words, no penalty for ancestral SNPs in case it is a split.

   for (terminal_haplogroup in terminal_deriveds)
   {
      # recalculate score for upstream derived haplogroups with terminals that are all aDNA damage
      # the new score has no penalty for ancestral SNPs, just like a terminal without aDNA damage.
      # then the score for the terminal is calculated again, with the new upstream derived score.

      if (terminal_deriveds[terminal_haplogroup] == 1 && terminal_haplogroup in upstream_derived_haplogroups)
      {
         if (downstream_derived_not_damage_counts[upstream_derived_haplogroups[terminal_haplogroup]] == 0)
         {
            if (recalculated_scores[upstream_derived_haplogroups[terminal_haplogroup]] == 0)
            {
               temp_old_score = scores[upstream_derived_haplogroups[terminal_haplogroup]]
              
               # temporarily mark the upstream derived haplogroup as "terminal" for purposes of recalculation of the score
               terminal_deriveds[upstream_derived_haplogroups[terminal_haplogroup]] = 1
               calculate_score(upstream_derived_haplogroups[terminal_haplogroup])
               terminal_deriveds[upstream_derived_haplogroups[terminal_haplogroup]] = 0
               recalculated_scores[upstream_derived_haplogroups[terminal_haplogroup]] = 1

               temp_new_score = scores[upstream_derived_haplogroups[terminal_haplogroup]]
            }

            calculate_score(terminal_haplogroup)
            recalculated_scores[terminal_haplogroup] = 1
         }
      }
   } 
}

function haplogroup_from_path(path)
{
   sub(/.*>/, "", path)
   return path
}

function print_derived_haplogroup(new_path,   upstream_derived)
{
  if (stored_haplogroup == "" || stored_short_path == "")
     return

  if (index(new_path, stored_haplogroup) == 0 || sample_is_older_than_formed_date_of_haplogroup(haplogroup_from_path(new_path)))
  {
    terminal = 1
  }
  else
  {
    terminal = 0
  }

  write_haplogroup(stored_derived, stored_snps, stored_derived_reads, stored_aDNA_damage, stored_full_path, terminal, stored_haplogroup)

  calculate_score(stored_haplogroup)

  if (aDNA_damages[stored_haplogroup] == "False")
  {
     upstream_derived = upstream_derived_haplogroups[stored_haplogroup]
     while (upstream_derived != "")
     {
        total_haplogroups_below_not_aDNA_damages[upstream_derived]++
        upstream_derived = upstream_derived_haplogroups[upstream_derived]
     }
  }

  stored_haplogroup = "" 
}

function write_haplogroup(derived, snps, derived_reads, aDNA_damage, full_path,  terminal_derived, haplogroup,   gap,  exclude)
{
   if (full_path == "")
   {
      return
   }

   haplogroups_by_path[full_path] = haplogroup

   short_path = calculate_short_path(full_path)
   upstream_derived_haplogroups[haplogroup] = find_upstream_derived_haplogroup(full_path)
   upstream_intervening_ancestrals[haplogroup] = find_upstream_intervening_ancestral(short_path)

   if (derived > 0)
   {
      states[haplogroup] = "+"
   }
   else
   {
      states[haplogroup] = "-"
   }
 
   if (derived == 0)
   {
      gap = 0
      exclude = "x"
   }
   else 
   {
      gap_short_path = short_path
      gap = gsub(/>/, "", gap_short_path)
      gap -=1
  
      if (gap < 0)
      {
         gap = 0
      }

      exclude = ""
   }

   deriveds[haplogroup] = derived
   total_snps[haplogroup] = snps

   if (derived > 0)
   {
      total_derived_reads_for_haplogroup[haplogroup] = derived_reads
      formed_dates[haplogroup] = find_formed_date(full_path)
   }
   else
   {
      total_derived_reads_for_haplogroup[haplogroup] = 0
      formed_dates[haplogroup] = 0
   }

   aDNA_damages[haplogroup] = aDNA_damage
   gap_from_upstream_derived_haplogroups[haplogroup] = gap
   gap_years_from_upstream_derived_haplogroup[haplogroup] = calculate_gap_years(upstream_derived_haplogroups[haplogroup], haplogroup)
   short_paths[haplogroup] = exclude short_path
   terminal_deriveds[haplogroup] = terminal_derived

   if ((derived > 0 && upstream_derived_haplogroups[haplogroup] != "") && 
        !sample_is_older_than_formed_date_of_haplogroup(haplogroup))
   {
      downstream_derived_counts[upstream_derived_haplogroups[haplogroup]]+=1
 
      if (aDNA_damage == "False")
      {
          downstream_derived_not_damage_counts[upstream_derived_haplogroups[haplogroup]]+=1 
      }
   }

   if (terminal_derived == 1 && aDNA_damage == "False")
   {
       add_haplogroup_to_blacklist(haplogroup)       
   }
}

function find_tied_top_score_haplogroups(top_score_haplogroups_array,      haplogroup, top_score, score_count, score_haplogroups)
{
   top_score = 0
   split("", score_count)

   for (haplogroup in scores)
   {
      if (haplogroup != "" && scores[haplogroup] >= top_score)
      {
         if (scores[haplogroup] > top_score)
         {      
            top_score = scores[haplogroup]
         }
         score_count[top_score]++
         score_haplogroups[top_score] =  score_haplogroups[top_score] " " haplogroup
      }
   }

   if (score_count[top_score] > 1)
   {
      return score_haplogroups[top_score] ""
   }
  
   return ""   
}
 
function find_haplogroup_in_derived_path(haplogroup, upstream_derived_path,    len, i, upstream_derived_path_values, upstream_derived_paths_keys)
{
   len = split(upstream_derived_path, upstream_derived_path_values)
  
   for (i=1; i <= len; i++)
   { 
      upstream_derived_path_keys[upstream_derived_path_values[i]] = ""
   }
  
   return haplogroup

   if (haplogroup in upstream_derived_path_keys)
   {
      return haplogroup
   }
   
   return ""
}

function find_upstream_common_derived_haplogroup(tied_haplogroups,      i, common_upstream_derived_haplogroup, upstream_derived_haplogroup)
{
    common_upstream_derived_haplogroup = upstream_derived_haplogroups[tied_haplogroups[1]]

    for (i = 2; i <= length(tied_haplogroups); i++)
    {
       while ((upstream_derived_haplogroup = upstream_derived_haplogroups[tied_haplogroups[i]]) == "")
       {
          upstream_derived_paths[i] = upstream_derived_paths[i] " " upstream_derived_haplogroup 
       }
      
       while (find_haplogroup_in_derived_path(common_upstream_derived_haplogroup, upstream_derived_paths[i]) == "")   
       {
         common_upstream_derived_haplogroup = upstream_derived_haplogroups[common_upstream_derived_haplogroup]
       }
   
       if (common_upstream_derived_haplogroup == "")
       {
          return ""
       }
    }
       
    return common_upstream_derived_haplogroup
}

function break_ties(    tied_haplogroups_list, tied_haplogroups)
{
    tied_haplogroups_list = find_tied_top_score_haplogroups()

    if (tied_haplogroups_list == "")
    { 
       return
    }
   
    split(tied_haplogroups_list, tied_haplogroups, " ")    
    split("", non_aDNA_damage_tied_haplogroups)
    non_aDNA_damage_tied_count = 0

    for (i=1; i <= length(tied_haplogroups); i++)
    {
       if (aDNA_damages[tied_haplogroups[i]] == "False")
       {
          non_aDNA_damage_tied_count++
          non_aDNA_damage_tied_haplogroups[non_aDNA_damage_tied_count] = tied_haplogroups[i]
       }
    }

    # boost score of single non-aDNA damage tied haplogroup to break tie

    if (non_aDNA_damage_tied_count == 1)
    {
       scores[non_aDNA_damage_tied_haplogroups[1]]++
       return
    } 

    # more than one tied non-aDNA damage tied haplogroup among others that are aDNA damage 

    if (non_aDNA_damage_tied_count > 1 &&  non_aDNA_damage_tied_count < length(tied_haplogroups))
    {
       # boost scores of non-aDNA_damage tied haplogroups

       for (i=1; i <= length(non_aDNA_damage_tied_haplogroups); i++)
       {
          scores[non_aDNA_damage_tied_haplogroups[i]]++
       }

       common_upstream_derived_haplogroup = find_upstream_common_derived_haplogroup(non_aDNA_damage_tied_haplogroups)

       # boost score of the common upstream derived haplogroup of the non-aDNA damage tied haplogroups to their new score +1 
       # to make it the top score

       scores[common_upstream_derived_haplogroup] = scores[non_aDNA_damage_tied_haplogroups[1]]+1
      
       return
    }

    # only tied aDNA damage haplogroups

    common_upstream_derived_haplogroup = find_upstream_common_derived_haplogroup(tied_haplogroups)

    # boost score of common upstream derived haplogroup to the previous top score +1
    scores[common_upstream_derived_haplogroup] = scores[tied_haplogroups[1]]+1
}

function find_formed_date(full_path  ,n, haplogroups)
{
   n = split(full_path, haplogroups, ">")
   
   if (n < 2)
   {
      return 0
   }
   
   return TMRCAlookup[haplogroups[n-1]]
}


function print_haplogroups(  n, i, path, haplogroup)
{
    for (path in haplogroups_by_path)
    {
       haplogroup = haplogroups_by_path[path]

       print states[haplogroup], deriveds[haplogroup] "/" total_snps[haplogroup], aDNA_damages[haplogroup], scores[haplogroup], short_paths[haplogroup], path
    }
}

function sample_is_older_than_formed_date_of_haplogroup(haplogroup)
{
   return sample_age > 0 && formed_dates[haplogroup] > 0 &&  sample_age > formed_dates[haplogroup]
}
   
function is_aDNA_damage(snps, derived, total_reads, total_ancestral_reads, total_derived_reads, derived_read_ancestral_allele, ancestral_read_derived_allele, ancestral_read_genotype, derived_read_genotype, haplogroup)
{
   if (haplogroup == "")
   {
      return ""
   }
  
   if ((derived == 1 && total_derived_reads <= 2 &&
       ((derived_read_ancestral_allele == "C" && derived_read_genotype == "T") || 
        (derived_read_ancestral_allele == "G" && derived_read_genotype == "A"))) ||
      (derived == 0 && total_ancestral_reads == 1 && 
       ((ancestral_read_derived_allele == "C" && ancestral_read_genotype == "T") || 
        (ancestral_read_derived_allele == "G" && ancestral_read_genotype == "A"))))
   {
      aDNA_damages[haplogroup] = "True"
      return "True"
   }
   else 
   {
      aDNA_damages[haplogroup] = "False"
      return "False"
   }
}

{ 
  if ($1 ~ "^#")
  {
     next;
  }

  old_path = path
  path = $NF
  n = split ($NF, haplogroups, ">")

  haplogroup = haplogroups[n] 
  state = $1 
  genotype = $5
  ancestral_allele = $6
  derived_allele = $7
  ancestral_reads = $8
  derived_reads = $9
  snp_names = $11

  if (haplogroup != old_haplogroup)
  {
     aDNA_damage = is_aDNA_damage(snps, derived, total_reads, total_ancestral_reads, total_derived_reads, derived_read_ancestral_allele, ancestral_read_derived_allele, ancestral_read_genotype, derived_read_genotype, old_haplogroup)   

     if (old_haplogroup != "" && find_upstream_blacklisted_haplogroup(old_path) == "")
     {
        # print "*** find_upstream_blacklisted_haplogroup(old_path)=" find_upstream_blacklisted_haplogroup(old_path) 
        if (derived != 0)
        {
           print_derived_haplogroup(old_path)

           store_derived_haplogroup(derived, snps, total_derived_reads, aDNA_damage, old_path, old_haplogroup)
        }
  
        if (derived == 0)
        {
           if (aDNA_damage == "False" && find_upstream_blacklisted_haplogroup(old_path) == ""  && find_upstream_intervening_ancestral(calculate_short_path(old_path)) != "")
           {
              add_haplogroup_to_blacklist(old_haplogroup)       
           }
       
           write_haplogroup(derived, snps, 0, aDNA_damage, old_path, 0, old_haplogroup)
 
           calculate_score(old_haplogroup)
        }
     }

     derived = 0
     snps = 0
   
     old_derived_read_ancestral_allele = derived_read_ancestral_allele
     old_derived_read_genotype = derived_read_genotype

     old_haplogroup = haplogroup
     old_total_reads = total_reads
     old_total_ancestral_reads = total_ancestral_reads
     old_total_derived_reads = total_derived_reads

     total_reads = 0
     total_ancestral_reads = 0
     total_derived_reads = 0

     derived_read_ancestral_allele = ""
     ancestral_read_derived_allele = ""
  }

  if (state == "+")
  {
     derived++
     total_derived_reads += derived_reads
    
     derived_read_ancestral_allele = ancestral_allele
     derived_read_genotype = genotype
  }
 
  if (state == "-")
  {
     total_ancestral_reads += ancestral_reads
     ancestral_read_derived_allele = derived_allele
     ancestral_read_genotype = genotype 
  }

  if (state != "?")
  {
     snps++
     total_reads += (ancestral_reads + derived_reads)
  }
}

END {
  print_derived_haplogroup(old_path)

  if (haplogroup != "Ξ")
  {
     aDNA_damage = is_aDNA_damage(snps, derived, total_reads, total_ancestral_reads, total_derived_reads, derived_read_ancestral_allele, ancestral_read_derived_allele, ancestral_read_genotype, derived_read_genotype, old_haplogroup)   

     if (old_haplogroup != "" && find_upstream_blacklisted_haplogroup(old_path) == "")
     {
        if (derived != 0)
        {
           write_haplogroup(derived, snps, aDNA_damage, total_derived_reads, old_path, 1, old_haplogroup)
           calculate_score(old_haplogroup)
        }
  
        if (derived == 0)
        {
           write_haplogroup(derived, snps, 0, aDNA_damage, old_path, 0, old_haplogroup)
        }

        calculate_score(old_haplogroup)
     }
  }

  recalculate_scores()

  if (do_not_break_ties == 0)
  {
     break_ties()
  }

  print_haplogroups()
}
' | sort -k6,6 | cut -f 1-5 | awk -v sample_age=$sampleAge '
BEGIN {
   if (sample_age > 0)
   {
      print "#Sample age\t" sample_age
   }
   print "#State\tDerived SNPs/Total SNPs\tpotential aDNA damage\tScore\tHaplogroup path down from the last derived haplogroup at this level"
}
{ print }
'
