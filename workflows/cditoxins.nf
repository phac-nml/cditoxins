/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_cditoxins_pipeline'

include { BLAST_MAKEBLASTDB    } from '../modules/nf-core/blast/makeblastdb/main' 
include { BLAST_BLASTN         } from '../modules/nf-core/blast/blastn/main' 
include { FILTERING_BLAST      } from '../modules/local/filtering/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INITIALIZE CHANNELS FROM PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_reference_genes = file(params.reference_genes, checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CDITOXINS {

    take:
    // A channel of tuples of ({meta}, assembly)
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = Channel.empty()

    //
    // Filter empty assemblies and print list of empty assemblies to file
    //
    ch_samplesheet
        .map {meta, assembly -> tuple(meta, assembly[0]) }
        .branch { meta, assembly -> 
                pass: assembly.size() > 0
                empty: assembly.size() == 0
                unknown: true 
                }
        .set { ch_assemblies }

    ch_assemblies.empty
        //.map { meta, assembly -> meta.id }
        .map { it[0].id + "," + it[1].toString() + "," + "Assembly is empty - will not run toxin detection"}
        .collectFile(name: "errors.csv", newLine: true, storeDir: params.outdir)
        .set {ch_assembly_empty}
    ch_assembly_empty.view { v -> "$v is empty"}

    //
    // Generate BLASTN db of reference genes
    //
    ch_reference_fasta = Channel.fromPath(ch_reference_genes)
        .map { fasta -> tuple([id: fasta.simpleName], fasta) }

    BLAST_MAKEBLASTDB(
        ch_reference_fasta
    )
    ch_versions = ch_versions.mix(BLAST_MAKEBLASTDB.out.versions)

    BLAST_MAKEBLASTDB.out.db
        .first()
        .set { ch_blast_db }

    //
    // Run BLASTN on assemblies    
    //
    BLAST_BLASTN(
        ch_assemblies.pass, ch_blast_db
    )
    ch_versions = ch_versions.mix(BLAST_BLASTN.out.versions)

    // Print list of failed assemblies based on BLASTN output report filesize
    ch_reports = BLAST_BLASTN.out.txt
        .branch { meta, report -> 
                    pass: report.size() > 0
                    empty: report.size () == 0
                    unknown: true
                    }
        .set {ch_reports_status}
    ch_reports_status.empty.view { v -> "$v has nohits in blast"}

    // Output a list of assemblies with nohits in BLASTN, as they don't appear in BLASTN output 
    ch_reports_status.empty
        .map { meta, report -> meta.id }
        .collectFile(name: "nohits.csv", newLine: true, storeDir: params.outdir)
        .set {ch_reports_nohits}

    // Combine all BLASTN reports together for successful samples
    ch_reports_status.pass
        .map{ meta, report -> report }
        .collect()
        .set { ch_blast_report }

    //
    // Filtering and processing BLASTN results
    //
    FILTERING_BLAST(
        ch_blast_report, file(params.input), ch_reports_nohits.ifEmpty(file(params.nohits))
    )
    ch_versions = ch_versions.mix(FILTERING_BLAST.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'cditoxins_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
